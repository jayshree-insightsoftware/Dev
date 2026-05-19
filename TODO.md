# TODO

## Phase 1 -- Discovery and inventory

- [x] Profile Account table (completeness, types, channel distribution)
- [x] Profile Contract table (status fields, ARR fields, Bill To relationships)
- [x] Profile D&B Connect Company Profile table (DUNS fields, hierarchy)
- [ ] Profile Contact table (3.4M rows)
- [ ] Profile Opportunity table (581K rows)
- [ ] Profile Lead table (1.8M rows)
- [ ] Profile Case table (3.8M rows)
- [ ] Resolve BuyerGroupMember access (request admin access or confirm Mike Hooker as query proxy)

## Phase 2 -- Concept exploration

- [x] Direct vs Indirect channel classification ($75.5M ARR impact)
- [x] DUNS duplicate analysis (9,736 groups, three patterns)
- [x] Account type vs contract status mismatch (709 accounts, $1.34M)
- [ ] Country standardization mapping (272 variations to ISO standard)
- [ ] Industry standardization mapping (539 values to standard taxonomy)
- [ ] Fuzzy duplicate deep dive (categorize 9,100 pairs by type)
- [ ] DUNS mismatch root cause analysis (2,598 accounts)

## Phase 3 -- Mart design

- [ ] Propose Account quality mart (completeness scores, duplicate flags, consistency checks)
- [ ] Propose Data quality scorecard mart (weekly metrics across all tables)

## Phase 4 -- App development

- [ ] Build automated Data Quality Scorecard (14 checks, 5 dimensions)
- [ ] Deploy weekly scheduled run via Claude Code

## Deliverables created

- [x] Data Governance Proposal document (Word)
- [x] Data Quality Scorecard document (Word)
- [x] Account Data Quality Findings report (Markdown)
- [x] Former Customer Active Contracts export (Excel + CSV)
