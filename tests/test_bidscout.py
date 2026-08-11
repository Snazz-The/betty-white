"""Tests for BidScout. Run: python3 -m unittest discover -s tests -v"""

import sys
import unittest
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from bidscout.models import CompanyProfile, Opportunity, parse_date
from bidscout.scoring import rank, score_opportunity
from bidscout.sources import dedupe

TODAY = date(2026, 8, 11)


def make_opp(**kw):
    defaults = dict(
        notice_id="N1",
        title="Custodial Services for Federal Building",
        agency="GENERAL SERVICES ADMINISTRATION",
        naics="561720",
        description="Contractor shall provide custodial services and floor care.",
        posted_date=TODAY - timedelta(days=2),
        response_deadline=TODAY + timedelta(days=30),
        set_aside="Total Small Business Set-Aside",
        place_of_performance_state="TX",
        estimated_value=250000.0,
        url="https://sam.gov/opp/N1/view",
    )
    defaults.update(kw)
    return Opportunity(**defaults)


def make_profile(**kw):
    defaults = dict(
        name="Apex Facility Services LLC",
        naics_codes=["561720", "561730"],
        keywords=["custodial", "janitorial", "floor care"],
        exclusions=["asbestos"],
        set_asides=["Total Small Business"],
        states=["TX", "OK"],
        min_value=50000,
        max_value=3000000,
        min_days_to_respond=10,
        past_agencies=["GENERAL SERVICES ADMINISTRATION"],
    )
    defaults.update(kw)
    return CompanyProfile(**defaults)


class TestDisqualifiers(unittest.TestCase):
    def test_expired_deadline_disqualified(self):
        opp = make_opp(response_deadline=TODAY - timedelta(days=1))
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertTrue(r.disqualified)
        self.assertIn("Deadline passed", r.warnings[0])

    def test_too_tight_turnaround_disqualified(self):
        opp = make_opp(response_deadline=TODAY + timedelta(days=3))
        r = score_opportunity(opp, make_profile(min_days_to_respond=10), as_of=TODAY)
        self.assertTrue(r.disqualified)

    def test_exclusion_term_disqualifies(self):
        opp = make_opp(description="Removal of asbestos from ceiling tiles.")
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertTrue(r.disqualified)
        self.assertIn("asbestos", r.warnings[0])

    def test_ineligible_set_aside_disqualified(self):
        opp = make_opp(set_aside="HUBZone Set-Aside")
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertTrue(r.disqualified)

    def test_out_of_service_area_disqualified(self):
        opp = make_opp(place_of_performance_state="NY")
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertTrue(r.disqualified)

    def test_empty_states_means_nationwide(self):
        opp = make_opp(place_of_performance_state="NY")
        r = score_opportunity(opp, make_profile(states=[]), as_of=TODAY)
        self.assertFalse(r.disqualified)

    def test_no_capability_signal_disqualified(self):
        """Set-aside + past performance alone must not float an unrelated job."""
        opp = make_opp(
            title="Warehousing and Distribution Services",
            description="Contractor shall provide warehousing and inventory management.",
            naics="493110",
        )
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertTrue(r.disqualified)
        self.assertIn("outside your line of work", r.warnings[0])

    def test_keyword_only_match_survives_capability_gate(self):
        """A keyword hit with no NAICS match is still a real signal."""
        opp = make_opp(
            title="Base Support Services",
            description="Includes custodial and floor care tasks.",
            naics="999999",
        )
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertFalse(r.disqualified)


class TestScoring(unittest.TestCase):
    def test_ideal_match_is_strong(self):
        r = score_opportunity(make_opp(), make_profile(), as_of=TODAY)
        self.assertFalse(r.disqualified)
        self.assertEqual(r.band, "STRONG")
        self.assertGreaterEqual(r.score, 70)

    def test_exact_naics_beats_adjacent(self):
        exact = score_opportunity(make_opp(naics="561720"), make_profile(), as_of=TODAY)
        adjacent = score_opportunity(
            make_opp(naics="561790"), make_profile(), as_of=TODAY
        )
        self.assertGreater(exact.score, adjacent.score)

    def test_title_keyword_outweighs_body_keyword(self):
        in_title = score_opportunity(
            make_opp(title="Custodial Services", description="General work."),
            make_profile(keywords=["custodial"]),
            as_of=TODAY,
        )
        in_body = score_opportunity(
            make_opp(title="Support Services", description="Includes custodial work."),
            make_profile(keywords=["custodial"]),
            as_of=TODAY,
        )
        self.assertGreater(in_title.score, in_body.score)

    def test_word_boundary_prevents_false_positive(self):
        """'IT' should not match inside 'audIT'."""
        opp = make_opp(
            title="Audit Support Services",
            description="Financial audit and reconciliation support.",
            naics="541611",
        )
        p = make_profile(naics_codes=["541519"], keywords=["IT"], set_asides=[], states=[])
        r = score_opportunity(opp, p, as_of=TODAY)
        self.assertNotIn("IT", " ".join(r.reasons))

    def test_keyword_score_is_capped(self):
        many = [f"kw{i}" for i in range(20)]
        desc = " ".join(many)
        opp = make_opp(title=desc, description=desc, naics="999999")
        p = make_profile(
            naics_codes=["111111"], keywords=many, set_asides=[], states=[],
            past_agencies=[],
        )
        r = score_opportunity(opp, p, as_of=TODAY)
        # keyword cap (30) + value in range (8) + runway (6) = 44
        self.assertLessEqual(r.score, 44)

    def test_value_over_capacity_warns_not_disqualifies(self):
        opp = make_opp(estimated_value=9_000_000.0)
        r = score_opportunity(opp, make_profile(), as_of=TODAY)
        self.assertFalse(r.disqualified)
        self.assertTrue(any("exceeds your stated capacity" in w for w in r.warnings))

    def test_past_agency_adds_points(self):
        with_past = score_opportunity(make_opp(), make_profile(), as_of=TODAY)
        without = score_opportunity(
            make_opp(), make_profile(past_agencies=[]), as_of=TODAY
        )
        self.assertGreater(with_past.score, without.score)

    def test_reasons_are_populated(self):
        r = score_opportunity(make_opp(), make_profile(), as_of=TODAY)
        self.assertTrue(r.reasons, "every scored opp must explain itself")

    def test_score_never_exceeds_100(self):
        r = score_opportunity(make_opp(), make_profile(), as_of=TODAY)
        self.assertLessEqual(r.score, 100.0)


class TestRanking(unittest.TestCase):
    def test_rank_excludes_disqualified_and_sorts(self):
        opps = [
            make_opp(notice_id="A", naics="561720"),
            make_opp(notice_id="B", naics="999999", title="Unrelated Widget Supply",
                     description="Widgets."),
            make_opp(notice_id="C", response_deadline=TODAY - timedelta(days=1)),
        ]
        results = rank(opps, make_profile(), as_of=TODAY)
        ids = [r.opportunity.notice_id for r in results]
        self.assertIn("A", ids)
        self.assertNotIn("C", ids)
        scores = [r.score for r in results]
        self.assertEqual(scores, sorted(scores, reverse=True))

    def test_min_score_filter(self):
        opps = [make_opp(notice_id="A")]
        self.assertEqual(len(rank(opps, make_profile(), as_of=TODAY, min_score=99)), 0)

    def test_limit(self):
        opps = [make_opp(notice_id=f"N{i}") for i in range(10)]
        self.assertEqual(len(rank(opps, make_profile(), as_of=TODAY, limit=3)), 3)


class TestSources(unittest.TestCase):
    def test_dedupe_keeps_newest(self):
        old = make_opp(notice_id="X", posted_date=TODAY - timedelta(days=5),
                       title="Original")
        new = make_opp(notice_id="X", posted_date=TODAY, title="Amendment 1")
        result = dedupe([old, new])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].title, "Amendment 1")

    def test_parse_date_formats(self):
        self.assertEqual(parse_date("2026-08-11"), date(2026, 8, 11))
        self.assertEqual(parse_date("08/11/2026"), date(2026, 8, 11))

    def test_parse_date_rejects_garbage(self):
        with self.assertRaises(ValueError):
            parse_date("not a date")


if __name__ == "__main__":
    unittest.main()
