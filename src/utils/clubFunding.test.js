import { describe, expect, it } from "vitest";
import {
  calculateFundingTotal,
  countWords,
  validateFundingForm,
  validateFundingRows,
} from "./clubFunding.js";

describe("club funding calculations", () => {
  it("calculates each row and the overall total", () => {
    expect(
      calculateFundingTotal([
        { unitPrice: "12.50", quantity: "2" },
        { unitPrice: "3.33", quantity: "3" },
      ]),
    ).toBe(34.99);
  });

  it("counts words without treating repeated whitespace as extra words", () => {
    expect(countWords("  school   community\nbenefit ")).toBe(3);
  });
});

describe("club funding validation", () => {
  it("requires valid cost rows", () => {
    const result = validateFundingRows([
      { item: "", unitPrice: "0", quantity: "1.5" },
    ]);

    expect(result.hasErrors).toBe(true);
    expect(result.rowErrors[0]).toEqual({
      item: "Describe the item and include a product link if possible.",
      unitPrice: "Enter a value greater than $0.",
      quantity: "Enter a whole-number quantity of at least 1.",
    });
  });

  it("flags totals above $500 for Principal review", () => {
    const result = validateFundingForm({
      usageOfFunding: "This supports student learning.",
      costRows: [{ item: "Projector", unitPrice: "600", quantity: "1" }],
      signedForm: {},
    });

    expect(result.isValid).toBe(true);
    expect(result.total).toBe(600);
    expect(result.requiresPrincipalReview).toBe(true);
  });

  it("limits the usage response to 300 words", () => {
    const result = validateFundingForm({
      usageOfFunding: Array.from({ length: 301 }, () => "word").join(" "),
      costRows: [{ item: "Notebook", unitPrice: "2", quantity: "1" }],
      signedForm: {},
    });

    expect(result.isValid).toBe(false);
    expect(result.errors.usageOfFunding).toContain("300 words or fewer");
  });

  it("requires the signed Teacher Approval Form", () => {
    const result = validateFundingForm({
      usageOfFunding: "This supports student learning.",
      costRows: [{ item: "Notebook", unitPrice: "2", quantity: "1" }],
    });

    expect(result.isValid).toBe(false);
    expect(result.errors.signedForm).toBe(
      "Attach the signed Teacher Approval Form.",
    );
  });
});
