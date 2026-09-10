from pathlib import Path

from design.student.audits.design_interaction_audit import DesignInteractionAuditor


DESIGN = Path(r"C:\Users\user\Downloads\Upstudy-student-app-design\upstudy-student-app-design.html")


def test_design_inventory_keeps_reference_bytes_and_86_screens():
    report = DesignInteractionAuditor(DESIGN).assert_expected(86)

    assert report.sha256 == (
        "EF8F6E40D01B099631C1940628E623A6113E1ADA68CFF3DEC0F1F89DEFCD0868"
    )
    assert report.dialog_templates == 43
    assert report.screen_count == 86
