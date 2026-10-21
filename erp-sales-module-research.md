---
title: ERP Sales Module — Research and Product Blueprint
document_version: 1.0
schema_version: 1
research_as_of: 2026-10-19
language: en
audience: [product_managers, business_analysts, architects, developers, ai_agents]
scope: inquiry_to_quotation_with_order_to_cash_boundaries
design_baseline: B2B_goods_and_services
status: research_and_proposed_specification
priority_definitions:
  P0: required_before_production_use_of_inquiry_to_order
  P1: operational_scale_and_configuration_depth
  P2: industry_or_channel_specific_extension
evidence_policy: vendor_behavior_requires_source_reference; unlabelled_requirements_are_proposed_design
---

# ERP sales module: research and product blueprint

Research date: **19 October 2026**. This document explains established ERP patterns and proposes a practical foundation for a new ERP. The companion HTML file presents the same material as a navigable human guide.

## 1. Direct answer and scope

**Your understanding is correct for the first part of sales, but it stops too early.** Receiving an inquiry, assigning a salesperson, and preparing a quotation covers demand capture and offer preparation. An ERP also needs to carry the accepted offer into an order and connect that commitment with fulfilment, billing, receivables, and payment. ERPNext documents these connected selling records and several variations of the cycle. [S25]

For your immediate build, define two deep areas: **Inquiry Management** and **Quotation Management**. Give them a reliable handover to Sales Order Management. Delivery, invoicing, and accounting can be separate modules, with explicit ownership and interfaces.

The central product decision is this: **an inquiry records what the customer asked; a quotation records what your company offers.** They are linked records with different purposes. Generating a quotation creates a new document; it should not destroy or overwrite the inquiry.

### 1.1 What this blueprint assumes

- Primary baseline: a business selling goods or services to other businesses.
- Both new prospects and existing customers can inquire.
- Some requests are clear catalog requests; others require discovery, costing, engineering, or supplier input.
- A sales team may work across companies, branches, territories, currencies, languages, and channels.
- No industry, country, transaction volume, technology stack, or implementation budget has been fixed. Industry features and example thresholds below are recommendations to validate, rather than universal requirements.
- This is functional and architectural research. It does not claim to reproduce a particular installed ERP configuration or provide a tested implementation.

### 1.2 How to read evidence

**Documented behavior** describes a named product and has a source ID. **Recommended design** describes the new ERP proposed here. **Example** means illustrative data or policy, not an industry benchmark. Source IDs resolve to official links in section 26.

Public documentation was reviewed for SAP S/4HANA Sales, JD Edwards EnterpriseOne 9.2, ERPNext, Odoo 19, and Microsoft Dynamics 365 Sales. Dynamics 365 Sales is a CRM comparator, not evidence that all Microsoft ERP products behave identically. SAP Sales Cloud and SAP CPQ are separate products; their capabilities must not be silently attributed to core S/4HANA.

## 2. Terminology: the records you actually need

| Term | Plain meaning | Example | Important boundary |
| --- | --- | --- | --- |
| Party / account | Organization or individual you deal with | Acme Manufacturing | Identity persists across many requests |
| Contact | A person and their communication details | Acme's purchasing manager | Several contacts can belong to one account |
| Lead | An unqualified possible buyer | Someone who downloaded a brochure | A contact or lead is not itself a specific purchase request |
| Inquiry / enquiry | A request for information, availability, a solution, or a price | “Can you supply 100 control units?” | Can be incomplete; can come from an existing customer |
| Customer RFQ | A buyer's formal request for your price | A PDF with quantities and a response deadline | An inbound sales request |
| RFI / RFP | Request for information / proposal | A capability questionnaire or solution tender | May require technical responses, rather than immediate item pricing |
| Opportunity | A potential deal worth actively pursuing | An annual factory upgrade | Tracks commercial pursuit, probability, value, and expected decision |
| Estimate | An indicative budget or cost assessment | “Approximately ₹1–1.2 lakh, subject to scope” | Must declare assumptions and permitted use |
| Quotation | Your versioned commercial offer | Items, prices, delivery, payment, and validity | Separate from the customer's request and internal approvals |
| Proposal | A customer-facing package around an offer | Scope narrative, technical sheets, commercial quotation | A presentation artifact; not necessarily a different transaction type |
| Sales order | The controlled record of an accepted purchase | 60 units ordered against a quotation | Starts downstream execution subject to order release controls |
| Blanket agreement / contract | An agreement for repeated releases or a term | Quarterly call-offs against an annual agreement | Usually has its own consumption and validity rules |
| Supplier RFQ | Your request to a supplier for their price | Asking three vendors for components | Procurement-side document; do not confuse with customer RFQ |

**Documented behavior:** ERPNext describes Lead, Opportunity, Quotation, and Customer as connected but distinct concepts, and allows multiple routes through them. Its procurement RFQ is addressed to suppliers. [S26], [S23]

**Recommendation:** Model inquiries as first-class records even if your UI later calls them “Requests” or “RFQs.” Keep a lightweight opportunity optional for short, transactional sales. Use an opportunity for longer deals, forecast management, multiple stakeholders, competing proposals, or several related inquiries.

## 3. What established products actually demonstrate

### 3.1 Evidence-backed comparison

| Product and exact area | Documented pattern | What to borrow for your ERP |
| --- | --- | --- |
| SAP S/4HANA Sales — presales | Inquiries and quotations are optional presales documents; direct entry is possible. [S01] | Allow process shortcuts when the business already has the needed information |
| SAP S/4HANA — quotation processing | A quotation may reference an inquiry; customer outcomes include changes, rejection, and acceptance. Quotation items can be partially referenced by orders. [S02] | Support negotiation and line-level progress |
| SAP S/4HANA — copy control | Source/target relationships, field transfer, and completion rules govern document flow. Inquiry and quotation completion can use different rules. [S03], [S04] | Build explicit mapping and consumption policies |
| SAP S/4HANA Cloud — incomplete documents and approvals | Official help describes worklists for incomplete inquiries/quotations and workflows with release, rejection, or rework. [S05], [S06] | Missing-data worklists and controlled commercial release |
| JD Edwards EnterpriseOne 9.2 — CRM | Configured opportunity actions can create quotes or orders; qualification scripts support scored questions. [S08], [S09] | Reusable qualification questionnaires and CRM-to-transaction handover |
| JD Edwards EnterpriseOne 9.2 — Sales Order Management | Quote orders use order-entry infrastructure, can become whole or partial sales orders, and have configurable inventory effects. [S07], [S11] | Reuse commercial mechanics while keeping document meaning explicit |
| JD Edwards EnterpriseOne 9.2 — integration and output | Inbound EDI RFQs can create priced quote orders; proposal generation uses templates and transaction data. [S10], [S13], [S14] | Separate intake, validation, pricing, and document presentation |
| ERPNext — CRM and Selling | Leads/opportunities feed quotations; quotations can address leads or customers. Assignment, custom fields, pricing rules, and approval workflows are configurable. [S15], [S16], [S17], [S18], [S19], [S20], [S21], [S22] | A simple connected workflow, reusable masters, and gradual configuration |
| Microsoft Dynamics 365 Sales — supporting CRM comparator | Draft quotes are activated before customer use; revisions create new drafts and preserve revision numbering. [S27], [S28] | Freeze issued commercial content and retain revision history |
| Odoo 19 — CRM and Sales | Opportunities can create quotations; quotation settings support reusable offers and online confirmation options. Output can combine branded PDFs with transaction data. [S29], [S30], [S31] | Fast preparation, customer preview, and reusable output |

These are reference patterns, not a feature ranking. Absence from this table means “not established by this research,” not “the product cannot do it.” A specific deployment's edition, configuration, add-ons, and update level determine actual behavior.

### 3.2 Status names are not interchangeable

ERPNext's quotation documentation lists **Draft, Open, Ordered, Lost, Expired, Cancelled**. [S17] Dynamics 365 Sales documents **Draft / Active**, closing outcomes **Lost / Canceled / Revised**, and a new draft for a revision. [S28] SAP's quotation processing also tracks item reference completion. [S02]

Your ERP should have its own coherent state model. Do not concatenate every vendor's labels into one dropdown.

### 3.3 A useful SAP lesson about completion

SAP's copy-control training illustrates an inquiry item completing after its first reference, even for part of its quantity, while a quotation item can remain partly referenced until its quantity is consumed. These are configured completion rules, not a universal definition of inquiry closure. [S03]

For the proposed ERP, explicitly choose whether inquiry response completion means first response, all requirements addressed, or all requested quantity quoted. Keep that separate from whether the customer eventually orders.

### 3.4 Current ERPNext qualification

ERPNext's current CRM introduction states that its **develop version** announces planned CRM removal in version 17 and points users toward Frappe CRM. Treat this as a roadmap notice in that documentation, not proof that every deployed ERPNext version has removed CRM. The transactional selling patterns remain useful reference material. [S26]

## 4. Recommended operating model and ownership

### 4.1 Three responsibilities

1. **Understand demand:** capture, identify, assign, clarify, qualify, and decide whether to respond.
2. **Control the offer:** choose a solution, calculate price and cost, approve exceptions, issue a revision, negotiate, and record acceptance.
3. **Execute the commitment:** create and release orders; deliver goods or services; invoice and collect.

An existing customer can start directly with an inquiry or quotation. A repeat order under an agreement can start at the order. A clear, approved portal purchase can bypass a manual quotation. Preserve the source and applicable checks in every path.

### 4.2 Roles and accountability

| Role | Main responsibility | Boundary |
| --- | --- | --- |
| Sales coordinator / intake team | Triage, match parties, remove spam, route work | Cannot approve commercial exceptions by default |
| Salesperson / account owner | Own the relationship, scope, follow-up, and offer | Cannot approve their own exception |
| Sales manager | Priorities, assignment, delegated discount approval | Authority limited by company and thresholds |
| Estimator / engineer | Specifications, feasibility, BOM or service effort, lead time | Internal cost and technical review; no automatic authority to issue an offer |
| Procurement | Supplier prices and lead times | Supplier quotes remain separate from customer offers |
| Pricing / commercial team | Price rules, margin review, large-deal approval | Cannot silently replace an issued customer offer |
| Finance / credit team | Payment terms, credit, tax setup, order release policy | Credit approval does not equal customer acceptance |
| Legal / contract reviewer | Nonstandard terms and contractual wording | Version-specific approval |
| Sales operations / configuration admin | Templates, queues, rule publishing, reports | Configuration rights do not automatically grant business approval |
| Auditor | Trace documents, changes, and approvals | Read-only, with sensitive-field restrictions |
| Customer / authorized contact | Clarify, view permitted offer, accept or decline | Access limited to their authorized account and revision |

**SAL-001 [P0]:** Every active inquiry and opportunity MUST have one accountable owner or an accountable queue with a named queue owner. Contributors and watchers MAY be multiple.

**SAL-002 [P0]:** Cross-company, tenant, territory, and sensitive-field permissions MUST be enforced on the server and all exports, search results, attachments, APIs, and background jobs.

## 5. Inquiry management: what a record contains

### 5.1 Capture a small amount first

Do not demand every field at intake. A useful minimum is **source, received time, original request, and an identifier**. If a reply route is unknown, save the inquiry into triage with “contact needed.” Full customer creation, SKU selection, quantity, budget, and delivery details can come later.

**INQ-001 [P0]:** Capture incomplete requests without invented values. Represent unknown quantity as null, not zero or one. A zero value must have an explicit business meaning.

### 5.2 Header data dictionary

| Field / group | Purpose | Required at receipt? | Required later? |
| --- | --- | --- | --- |
| inquiry_id, display_number, tenant_id, company_id | Stable identity and isolation | ID and tenant yes; company may await routing | Company fixed before commercial processing |
| source_channel, source_system, external_message_id | Provenance and duplicate prevention | Yes; generate a manual source ID where needed | Retained permanently according to policy |
| received_at, original_timezone | SLA start and traceability | Yes | Store UTC; display local time |
| raw_subject, raw_request, attachment_refs | Original customer evidence | Some original content or evidence reference | Never overwritten by normalized text |
| party_id / provisional_party, contact_id / reply_route | Who is asking and how to respond | May be unknown | Confirm recipient before sending |
| customer_reference, RFQ_number, project_reference | Buyer's tracking references | Optional | Required for tenders where applicable |
| inquiry_type, product_family, industry | Select the right form and team | May start “unclassified” | Needed before specialized validation |
| owner_id / queue_id, team, territory, branch | Accountability and routing | Assign immediately or queue | No unowned active work |
| requirement_summary, customer_objective | Concise understanding | Can be rough | Salesperson validates it |
| response_due_at, requested_delivery_window | When response and supply are needed | Optional | Confirm or state assumptions before offer |
| budget_range, currency, decision_process | Qualification context | Optional | Do not make budget universally mandatory |
| opportunity_id, related_inquiry_ids | Relationship to the wider deal | Optional | Use when helpful |
| work_state, closure_outcome, priority | Work management | State yes; closure outcome only on closure | Controlled transitions |
| template_id, template_version, custom_fields | Versioned capture structure | Default generic form allowed | Pin version on the record |
| completeness_issues, next_action, next_action_due | Explain missing data and next work | Calculated / assigned | Required for active managed work |
| confidentiality, communication_permissions | Access and contact preferences | Defaults apply | Enforced when communicating |
| row_version, created_by, updated_by | Concurrency and audit | System generated | Always |

### 5.3 Inquiry line data dictionary

An inquiry can have zero structured lines initially. Preserve free text until a person or approved automation can resolve it.

| Field / group | What it represents |
| --- | --- |
| line_id, customer_line_reference | Stable line identity, independent of display order |
| original_description | Exact requested wording or evidence pointer |
| normalized_description | Your interpreted requirement, separate from original |
| item_id / candidate_item_ids | Confirmed catalog match or proposed candidates |
| requirement_kind | Stock good, configured good, manufactured item, service, project, other |
| specification and version | Grade, dimensions, drawing, compatibility, service scope |
| quantity, UOM, quantity_range | Confirmed value, range, or unknown |
| delivery_window, location, schedule | One or several requested deliveries |
| substitution_allowed | Whether equivalents may be offered |
| budget / target_price | Customer expectation, not your approved selling rate |
| requirement_status | Unknown, under review, quoteable, quoted, no-bid, withdrawn |
| missing_fields and clarifications | Structured issues with responsible person and due date |
| evidence_refs, verified_by, verified_at | Source and confirmation of interpreted values |
| supplier_or_engineering_dependencies | Work required before a firm offer |

**INQ-002 [P0]:** A customer line and internal item MUST NOT be treated as identical. One customer requirement may become several offered items, and several requirements may map to one configured solution. Retain an explicit many-to-many mapping with quantities and rationale.

### 5.4 The salesperson's inquiry workbench

Provide the original message and attachments, a compact interpreted requirement, unresolved questions, customer history, owner, deadlines, next action, and related quotes in one place. Include actions for **Request clarification**, **Assign specialist**, **Mark no-bid**, **Create draft quote**, and **Close inquiry**. Show why an action is blocked and link directly to the missing field.

## 6. How inquiries arrive and what each channel needs

**Documented anchors:** ERPNext describes email, web forms, incomplete ecommerce orders, and spreadsheet imports for lead capture. JD Edwards documents EDI customer RFQs that become quote orders. [S18], [S10] The broader channel design below is a recommendation; native availability differs by product and integration.

| Channel | Typical input | Recommended capture method | Key controls |
| --- | --- | --- | --- |
| Email | Free text, PDF RFQ, spreadsheet, drawing | Monitored mailbox; thread linkage; attachment storage | Message-ID dedupe, sender matching, malware checks, bounce handling |
| Website form | Structured fields plus message | Form mapped to an inquiry template | Spam controls, validation, source attribution, consent fields where needed |
| Customer portal | Logged-in customer RFQ | Account-linked structured request with line upload | Account permissions, company selection, revision tracking |
| Phone / meeting / walk-in | Spoken or handwritten requirement | Salesperson enters notes and confirmation task | Attribution to recorder; distinguish customer statements from interpretation |
| WhatsApp / social / chat | Short, fragmented messages and media | Authorized channel connector into a shared conversation record | Provider-event dedupe, attachment linkage, account matching, send-policy controls |
| Salesperson / partner entry | Prospect visit, referral, distributor request | Manual or mobile entry | Original source and partner attribution; permission limits |
| EDI / B2B network | Customer RFQ transaction | Trading-partner mapping into validated canonical intake | Partner identity, schema validation, UOM/item mapping, reject queue |
| Tender / procurement portal | RFQ/RFP package with deadline | Authorized integration or supervised import | Tender revision, submission deadline/timezone, acknowledgment and response proof |
| Marketplace / ecommerce | Product inquiry or unfinished basket | Supported API/webhook or batch import | Customer identity, cart context, duplicate events, source restrictions |
| Spreadsheet / legacy import / API | Batch records or external CRM demand | Staged import with preview and error report | External keys, row errors, dry-run, idempotent retry |

### 6.1 A message is not automatically a new inquiry

**INQ-003 [P0]:** Match incoming events to conversations first. Append clarifications to an existing inquiry when they concern the same requirement. Create a separate inquiry for an independent purchase need; allow a person to split or merge with an audit trail.

Recommended matching order: explicit inquiry reference; known provider thread linked to an inquiry; known customer RFQ reference within company; then a human-reviewed candidate match. A shared email domain or phone number alone is insufficient to merge business requests.

**INQ-004 [P0]:** Preserve both the channel source and marketing attribution. “Email” is a transport channel; “trade fair referral” may be the acquisition source. They answer different reporting questions.

## 7. Inquiry lifecycle and transition rules

The states below are **recommended for your ERP**, not claimed as a common vendor status list.

### 7.1 Work states

| Current state | Meaning | Next action / allowed transition | Guard |
| --- | --- | --- | --- |
| RECEIVED | Request safely recorded | TRIAGE | Original source stored |
| TRIAGE | Match identity, classify, dedupe, assign | AWAITING_CUSTOMER, SCOPING, READY_TO_QUOTE, ON_HOLD, CLOSED | Owner or queue assigned |
| AWAITING_CUSTOMER | Specific questions sent; waiting for reply | SCOPING, READY_TO_QUOTE, ON_HOLD, CLOSED | Record questions, last contact, and follow-up date |
| SCOPING | Sales, engineering, or procurement resolving demand | AWAITING_CUSTOMER, READY_TO_QUOTE, ON_HOLD, CLOSED | Identify internal dependency and responsible person |
| READY_TO_QUOTE | Selected scope meets draft-generation gate | QUOTING; back to SCOPING if scope changes | No unresolved blocker for selected scope |
| QUOTING | One or more draft offers being prepared | SCOPING, AWAITING_CUSTOMER, READY_TO_QUOTE, CLOSED | Track residual unaddressed scope separately |
| ON_HOLD | Deliberate pause | Previous active state or CLOSED | Reason, owner, review date, and SLA pause policy |
| CLOSED | Inquiry response work finished | Reopen to TRIAGE or SCOPING by authorized action | Closure outcome and scope disposition required |

### 7.2 Closure outcomes and separate progress

Use a separate `closure_outcome`: `QUOTED_COMPLETE`, `PARTIALLY_QUOTED`, `INFORMATION_PROVIDED`, `NOT_QUALIFIED`, `NO_BID`, `DUPLICATE`, `SPAM`, `NO_RESPONSE`, or `CUSTOMER_WITHDREW`.

Keep `response_coverage = NONE | PARTIAL | FULL` independent of work state. Closing an inquiry as quoted does not mark its opportunity won. An information-only inquiry may close without any quote. A no-bid decision should preserve the reason, such as unsupported specification, impossible date, commercial mismatch, or unavailable capacity.

**INQ-005 [P0]:** Closing response work MUST require every in-scope requirement to be either addressed by an issued response/offer or explicitly dispositioned. Partial closure MUST state what was excluded and why.

**INQ-006 [P0]:** Reopening MUST retain previous closure, timestamps, and communications. New customer requirements MUST form a new requirement revision or a related inquiry; do not rewrite the original evidence.

### 7.3 Inquiry line coverage is not order consumption

Two alternative quotations can respond to the same requirement. Do not add their quantities and claim twice as much inquiry demand. Mark response coverage against requirement identities and versions. Separately calculate what accepted quotation quantities remain available for order conversion.

### 7.4 No-response and follow-up policy

Use a configurable contact cadence with a stop condition. Example only: reminder after two business days, second reminder after five, review for closure after ten. Large tenders or contractual response windows require different calendars. A buyer saying “come back next quarter” should get an agreed review date rather than an automatic loss.

## 8. Qualification, assignment, and missing information

### 8.1 What to establish

Ask what the customer needs, whether you can supply it, when and where it is needed, who can clarify it, and what kind of response they expect. Budget, authority, competition, and decision process help larger deals, but should not block every straightforward quotation.

JD Edwards' qualification scripts demonstrate configurable questions and response scoring. [S09] Use such scoring to prioritize work. It must not replace hard requirements such as an unambiguous specification for a firm offer.

### 8.2 Assignment policy

**INQ-007 [P0]:** Route by existing account owner first, then company/product/territory/language rules, then an eligible fallback queue. Allow manager override with reason. Retain assignment history and escalate aged unclaimed work.

ERPNext's assignment rules support round-robin, load-balancing, and field-based assignment. [S19] For your implementation, explicitly add eligibility, absence coverage, capacity, and escalation rules rather than assuming the balancing algorithm handles these automatically.

### 8.3 Different stages need different completeness

| Stage | Minimum gate | What may still be unknown |
| --- | --- | --- |
| Save intake | Source, time, original evidence, tenant | Party, SKU, quantity, budget |
| Send clarification | Valid reply route and authorized sender | Most commercial details |
| Create quote draft | Selected interpretable scope, provisional party, responsible preparer | Some prices, tax, internal costing |
| Approve commercial offer | Resolved approval-relevant values or explicit exceptions | Only permitted, documented assumptions |
| Issue firm offer | Confirmed recipient, seller, specifications, quantity/pricing basis, currency, tax treatment, validity, delivery basis, terms, cleared approvals | Only clearly stated nonblocking assumptions |
| Record acceptance | Exact issued revision, authorized accepting party, accepted scope, time/evidence | Order release may still need account/credit setup |
| Create / release order | Accepted firm offer or approved alternate route; customer/account setup; remaining quantity; applicable credit and release checks | No unresolved execution blocker for released scope |

**INQ-008 [P0]:** Completeness MUST be an actionable list of issues, not just a percentage. Each issue needs field or line, reason, severity, blocking stage, owner, and resolution. A 95% complete request can still be impossible to price.

### 8.4 Handling a half-baked inquiry

| Problem | Salesperson action | System behavior | Quote consequence |
| --- | --- | --- | --- |
| “Need control units urgently” | Ask application, model/specification, quantity, destination, deadline | Save immediately; create clarification checklist | No firm offer until selected scope is clear |
| Product known, quantity missing | Ask quantity; optionally give approved price bands | Store unknown or range, not fake quantity | Indicative unit-price response or budget estimate |
| Quantity known, specification ambiguous | Offer candidate matches; engineering review | Candidate items remain unconfirmed | Firm-issue blocker |
| Some lines clear, others unclear | Quote clear lines; list exclusions and pending questions | Partial response coverage; unresolved lines remain active | Partial quotation with explicit scope |
| Custom item absent from catalog | Request drawing and estimation | Provisional requirement plus engineering task | Budgetary estimate until controlled sellable specification exists |
| Supplier cost missing | Procurement requests supplier offers | Link procurement dependency and supplier validity | Block firm issue or require explicit cost-risk approval |
| Budget unknown | Continue reasonable qualification | Optional field; flag only where business policy requires | Usually not a quote blocker |
| No usable contact | Investigate source or keep in triage | Save record; block outbound reply | Cannot issue to an unknown recipient |
| Conflicting quantity in PDF and email | Ask which revision governs | Preserve both pieces of evidence; flag conflict | Block affected firm lines |
| Customer wants a rough budget only | State assumptions and estimate basis | `offer_basis=BUDGETARY`; restrict direct order conversion | Revalidate or create a firm revision before order |

**INQ-009 [P0]:** Extraction or AI assistance MAY suggest fields, but MUST retain evidence pointers, distinguish assumed from confirmed values, and require review for ambiguous specifications, quantities, dates, recipients, or prices. A document attachment is untrusted input and cannot instruct the system to bypass permissions or approvals.

## 9. Configurable inquiry forms and templates

Yes—different inquiries should use different forms. Avoid building a completely separate module for each industry. Use a stable common header, structured line types, and versioned extensions.

### 9.1 Keep four configuration concepts separate

| Configuration | Purpose | Example |
| --- | --- | --- |
| Intake form / questionnaire | What information to capture | Motor voltage, drawing revision, service site |
| Mapping and validation policy | How source fields become canonical data and what blocks a stage | Customer part number resolves to an approved SKU |
| Commercial preset | Default offer content and policy | Price list, payment terms, validity, standard services |
| Output / communication template | How the request or offer is presented | Branded PDF, clarification email, tender response |

ERPNext supports custom fields and standard-field property changes through Customize Form; JD Edwards separately documents qualification scripts and proposal templates. [S20], [S09], [S14] These support the distinction between capturing information and printing an offer.

### 9.2 Starter inquiry profiles

| Profile | Additional information | Before firm offer |
| --- | --- | --- |
| Stock / distribution | SKU or specification, quantity/UOM, ship-to, delivery need | Product identity and supply basis confirmed |
| Make to order | Drawing/version, material, tolerances, tooling, quantity breaks, inspection | Engineering feasibility, cost, lead time |
| Equipment / configured product | Capacity, options, environment, compatibility, installation | Valid configuration and required accessories |
| Professional service | Deliverables, assumptions, exclusions, location, effort/milestones | Scope, pricing model, acceptance criteria |
| Construction / project | BOQ, site, drawings, schedule, qualifications, exclusions | Scope boundaries, quantities or measurement basis |
| Export | Destination, currency, shipping responsibility and named place, documentation | Applicable trade and tax review |
| Support / renewal | Installed item or contract, term, service entitlement | Eligibility and commercial renewal basis |

### 9.3 Template governance

**CFG-001 [P0]:** Templates MUST have ID, version, owner, company scope, draft/published/retired lifecycle, effective dates, typed fields, stage-specific requirements, and change history. Existing inquiries MUST retain their original version; upgrades require an explicit, audited migration.

**CFG-002 [P0]:** Conditional fields MUST be validated server-side. Tenant-configurable expressions MUST use a constrained rule language; do not execute arbitrary user-supplied code.

**CFG-003 [P1]:** Support preview with representative requests, localization, attachment requirements, field-level access, rule priority, and a safe fallback when no specialized template matches.

Example rule: if inquiry type is `MANUFACTURED_PART`, drawing revision is mandatory before engineering approval. It is not mandatory merely to save an email inquiry.

## 10. Inquiry-to-quotation conversion: exactly what happens

“Extract a quotation” involves two separate operations: **extract structured requirements from the request**, then **construct an offer using approved business data**. Customer wording alone normally cannot determine your selling price, tax, delivery promise, or approved terms.

### 10.1 Three preparation modes

| Mode | When it fits | System work | Human responsibility |
| --- | --- | --- | --- |
| Manual | Custom solution, new item, unusual tender | Blank or partially mapped draft | Resolve scope, items, costs, price, terms |
| Assisted — recommended default | Most B2B selling | Copy verified requirements; propose masters, prices, terms, and questions | Confirm mappings and exceptions; review customer output |
| Rules-based automatic draft | Known customer, standard items, deterministic policy | Generate a draft from validated structured demand | Review or monitor exception queue |
| Automatic issue | Narrow approved catalog/contract flow | Issue only when every hard gate and policy passes | Business owner authorizes the policy and audits outcomes |

Automatic document creation does not imply automatic approval or sending. PDF generation is presentation automation; it is not commercial decision-making.

### 10.2 Recommended conversion algorithm

**CNV-001 [P0]:** `CreateQuotationFromInquiry` MUST execute an authorized, idempotent command:

1. Check tenant, company, permissions, current inquiry revision, and request idempotency key.
2. Select the requirement lines, scope, and quantities being addressed. Reject stale or withdrawn selections.
3. Resolve the recipient and seller. Preserve original account, contact, and address references.
4. Resolve catalog items, service scope, configuration, UOM conversions, and alternatives. Unresolved values remain explicit draft issues.
5. Copy customer intent and references using a versioned mapping policy. Create line-level source mappings, not just a header link.
6. Fetch approved defaults: customer agreement, price list, discounts, currency, payment terms, standard clauses, and delivery basis.
7. Calculate draft pricing, tax treatment, freight, and cost using the selected policies. Never interpret the customer's target price as an approved selling price.
8. Check supply/engineering/procurement dependencies and attach their evidence.
9. Evaluate completeness and approval triggers. Return field/line issues and the next responsible role.
10. Save a new **DRAFT** quotation with a source snapshot and mapping/policy versions in one transaction; record audit and outbox events.
11. Display the draft and a mapping summary. Leave the inquiry accessible with unresolved scope and next actions.

Generation MUST NOT mark the inquiry fully answered just because a draft exists. Use an issued response, or an explicit no-quote disposition, to determine response coverage.

### 10.3 Field mapping rules

| Inquiry data | Quotation result | Rule |
| --- | --- | --- |
| Customer / provisional party | Offered-to party | Verify identity; do not auto-create duplicate accounts |
| Contact / reply route | Recipient | Confirm authorization and destination before issue |
| Customer RFQ / line reference | Header and line references | Preserve exactly alongside internal numbers |
| Raw description | Source evidence link | Do not use unreviewed text as the final product specification |
| Confirmed specification | Offered specification | Explicit differences require a deviation statement |
| Requested quantity/UOM | Proposed quantity/UOM | Permit partial offer and documented conversions |
| Requested date | Requested-date reference | Separate from your offered delivery promise |
| Customer target price | Negotiation context | Not automatically the offered rate |
| Clarifications and attachments | Internal evidence and permitted customer attachments | Internal notes/costs must not leak into output |
| Intake template | Mapping policy selection | Do not assume it is also the PDF template |

### 10.4 Relationships and alternatives

- One inquiry can create several quotation families: alternative solutions, separate locations, companies, or phases.
- One quotation family has several revisions; only the currently available issued revision is actionable by default.
- A quotation revision can contain selected requirements from multiple inquiries only when company, party, currency, and commercial policy are compatible. Preserve every source link.
- A requirement can map to multiple quote lines, such as equipment, installation, and commissioning.
- An alternative item replaces a base item; an optional add-on supplements it. Do not total every mutually exclusive alternative as though the customer buys all of them. ERPNext and Odoo document these kinds of offer choices in their respective quotation features. [S17], [S32]

**CNV-002 [P0]:** Repeated conversion with the same idempotency key MUST return the same result. A different request that intentionally creates another option MUST have a distinct family/option identity and may refer to the same demand without increasing demand totals.

## 11. Quotation management: content and preparation

### 11.1 Quotation data dictionary

| Group | Required commercial content | Important controls |
| --- | --- | --- |
| Identity | Quote family, revision, seller/company, date, owner | Stable revision identity and visible revision number |
| Buyer | Account/prospect, offered-to contact, billing/ship-to basis | Address and recipient snapshot on issue |
| References | Inquiry/requirement versions, customer RFQ, opportunity, project | Source-to-offer traceability |
| Offer basis | Firm or budgetary; goods/services/project; pricing model | Budgetary offers cannot silently become firm orders |
| Validity | Valid-from, valid-until, timezone, acceptance deadline | Enforced at acceptance time, not just by a nightly job |
| Lines | Item/specification, quantity/UOM or measured basis, unit price, schedule | Stable line IDs and source mappings |
| Choices | Base, optional, alternative group, selected option | Compatible selections only; clear totals |
| Pricing | Price list/agreement, discounts, surcharges, freight, currency | Explainable calculation and controlled overrides |
| Tax | Tax category, jurisdiction basis, inclusive/exclusive mode, components | Explicit assumption if destination is provisional |
| Delivery / execution | Offered date or lead-time basis, destination, responsibilities | Separate requested date from offered date |
| Payment | Deposit, credit period, milestones, currency, schedule | Approval for deviations |
| Scope and terms | Deliverables, assumptions, exclusions, warranty/validity clauses | Versioned approved wording |
| Internal assessment | Cost estimate, margin, risk, approvals, feasibility | Excluded from customer-facing output |
| Customer artifacts | Issued PDF/HTML, allowed attachments, language | Store exact artifact and template version |
| Outcome | Acceptance/rejection/change evidence, loss reason | Tied to the exact revision and scope |

**QTN-001 [P0]:** An issued quotation MUST preserve the offer snapshot: recipient, addresses, item/specification descriptions, prices, tax basis, terms, source requirements, policy versions, and generated output. Later master-data changes MUST NOT silently change it.

### 11.2 What a salesperson does

1. Review the inquiry and customer context; confirm what is actually being offered.
2. Generate a draft or start directly for a known requirement.
3. Select products/services/configurations and any alternatives; confirm quantities and delivery basis.
4. Review system prices, estimated costs, effective discounts, and margin.
5. Obtain feasibility, supplier, credit, or terms review where applicable.
6. Submit triggered exceptions to authorized approvers.
7. Preview the exact customer document; confirm recipient and attachments; issue and send.
8. Record discussion and follow-up; create a new revision when commercial content changes.
9. Record acceptance, decline, expiry, or withdrawal with evidence.
10. Convert accepted scope to an order and confirm the downstream handover result.

ERPNext CRM Settings also documents quotation-validity defaults and optional carry-forward of emails/comments during conversion. [S24] The proposed ERP should link the same communication history without exposing internal content to the customer.

### 11.3 Creation routes

Support creation from an inquiry, opportunity, approved prior quote as a fresh draft, customer agreement, configured solution, or authorized portal request. Direct entry is valid. Copying an old offer must re-evaluate current prices, tax, terms, configuration, and delivery; historical values are a reference, not automatically a fresh commitment.

### 11.4 Budgetary and firm offers

`offer_basis = BUDGETARY | FIRM` describes intended commercial use. `pricing_model = FIXED | UNIT_RATE | TIME_AND_MATERIAL | MILESTONE | RECURRING` describes calculation. Keep these independent.

A budgetary offer can contain ranges, explicit assumptions, and exclusions. It must explain what is needed to become firm. A firm quote requires a sufficiently defined quantity or measurement basis, scope, price, and execution basis. The label alone does not determine legal effect; approved terms and the actual agreement govern. Do not automatically create an executable order from a budgetary estimate.

## 12. Pricing, costing, tax, and supply checks

### 12.1 Price and cost answer different questions

Price is what the buyer pays. Cost is your estimated expense. Margin is the difference measured against selling revenue. Procurement or engineering may estimate cost while sales chooses the selling price under commercial policy.

ERPNext documents conditional pricing rules; JD Edwards documents configurable repricing and controls for price fields on orders created from quotes. [S22], [S12] The deterministic policy below is a proposed design, not a claim that vendors use identical precedence.

### 12.2 Recommended calculation policy

**PRC-001 [P0]:** Define one explicit precedence, for example: valid customer agreement → customer price list → general price list → controlled manual rate. Evaluate eligible adjustments in declared order; define whether rules stack or are exclusive. Explain why every rate or adjustment applied.

**PRC-002 [P0]:** Record pricing date, quantity basis, UOM conversion, currency and FX source/date, price-list/rule versions, discount layers, rounding, and overrides. Use decimal money calculations and a declared rounding policy.

**PRC-003 [P0]:** Never silently reprice an issued quote. Changes require a new revision or an explicitly agreed adjustment mechanism already stated in the offer.

**PRC-004 [P0]:** Quantity changes and partial orders MUST recheck eligibility for tier prices, minimum order quantities, minimum charges, freight, and discounts. Either the accepted agreement guarantees the rate for partial releases, or the changed scope needs re-quotation/approval. Do not assume the 100-unit price is valid for a standalone 10-unit order.

### 12.3 Price waterfall

Recommended order: determine base rate; apply approved line adjustments; extend by quantity; allocate document discounts; calculate freight/surcharges; calculate applicable taxes on their configured bases; apply declared rounding. Tax-inclusive pricing or jurisdiction-specific freight taxation can require a different sequence. The tax engine owns these rules; the UI should show their effects rather than implement a second calculator.

Show internal cost freshness and assumptions. A missing cost is a risk condition, not automatically zero. Some businesses price against replacement cost, standard cost, supplier quotation, or project estimate; choose the basis and retain it.

### 12.4 Worked commercial example — illustrative only

Assumptions: 100 standard control units, flat approved rate basis, no quantity-tier commitment, amounts in INR, discount applied before tax, freight of ₹2,000 per shipment recovered at cost (the full-quote total assumes one shipment), and a hypothetical **18%** tax on discounted goods plus freight. This is arithmetic to explain the system, not a statement of the tax rate applicable to these goods.

| Calculation | Amount |
| --- | ---: |
| 100 × ₹1,120 list rate | ₹112,000 |
| 10% line discount | −₹11,200 |
| Net goods | ₹100,800 |
| Freight charged | ₹2,000 |
| Revenue / taxable base under this example's assumptions | ₹102,800 |
| Hypothetical tax: ₹102,800 × 18% | ₹18,504 |
| Customer total | **₹121,304** |
| Estimated goods cost: 100 × ₹800 | ₹80,000 |
| Estimated freight cost | ₹2,000 |
| Estimated gross profit excluding tax | ₹20,800 |
| Estimated gross margin: ₹20,800 / ₹102,800 | **20.23%** |

Markup would instead be ₹20,800 / ₹82,000 = 25.37%. Do not label markup as margin. If the policy allows the salesperson only a 5% discount, the requested 10% must go through the configured approval process.

### 12.5 Availability and delivery

**SUP-001 [P0]:** Display availability/capacity evidence and its timestamp. “In stock now” is not a promise that stock will still be available when the customer accepts. Default: quotation does not reserve stock; implement optional time-limited reservation as a separate controlled capability.

Separate stocked supply, purchase-to-order, manufacture-to-order, configured production, drop shipment, and services. Each needs a different feasibility/lead-time provider. A manufacturing offer may depend on engineering, BOM/routing cost, tooling, and capacity. A service offer may depend on staffing and agreed milestones.

**SUP-002 [P0]:** Recheck execution constraints at order handover/release. A changed supply situation must create a visible exception and customer-resolution task; do not silently overwrite an accepted delivery commitment.

## 13. Quotation lifecycle: avoid one overloaded status

All states in this section are **proposed design**. Track independent dimensions and derive a simple display label for users.

### 13.1 Independent dimensions

| Dimension | Recommended values | Question answered |
| --- | --- | --- |
| document_state | DRAFT, ISSUED, SUPERSEDED, WITHDRAWN | Is this version an actionable offer? |
| approval_state | NOT_REQUIRED, PENDING, APPROVED, REWORK_REQUIRED, REJECTED | Has internal authority cleared this version? |
| customer_decision | AWAITING, CHANGES_REQUESTED, PARTIALLY_ACCEPTED, ACCEPTED, DECLINED | What has the customer decided for the offered scope? |
| validity_state | NOT_YET_VALID, VALID, EXPIRED | Can new acceptance occur now? Computed from time and policy |
| transmission_state | NOT_SENT, QUEUED, PROVIDER_ACCEPTED, DELIVERED, FAILED | What do we know about outbound delivery? Per attempt |
| ordering_state | NOT_ORDERED, PARTIALLY_ORDERED, FULLY_ORDERED, CLOSED_REMAINDER | What accepted scope has become an order? |

“Viewed” is an optional event with evidence limits, not proof of acceptance. An email provider accepting a message is not proof that the buyer received or read it. “Won” belongs to an opportunity or a clearly defined commercial outcome; it is not interchangeable with “delivered” or “paid.”

### 13.2 User-visible lifecycle and actions

| User label | Typical stored state | Allowed action | Guard / effect |
| --- | --- | --- | --- |
| Draft | DRAFT, no pending approval | Edit, calculate, request review, discard | Draft only; no customer acceptance |
| Awaiting approval | DRAFT + PENDING | Approve, reject, request rework, withdraw request | Lock approval-relevant content |
| Rework required | DRAFT + REWORK_REQUIRED | Edit and resubmit | Retain comments and prior decisions |
| Ready to issue | DRAFT + APPROVED or NOT_REQUIRED | Issue | All hard issue gates pass |
| Issued / awaiting customer | ISSUED + AWAITING + VALID | Send/resend, follow up, accept, decline, revise, withdraw | Version is immutable |
| Changes requested | ISSUED + CHANGES_REQUESTED | Create new draft revision | Old offer handling follows explicit supersession policy |
| Partly accepted | ISSUED + PARTIALLY_ACCEPTED | Record more acceptance or close remaining scope | Validate quantities and option selection |
| Accepted / awaiting order | ISSUED + ACCEPTED, not fully ordered | Create order / resolve handover exception | Accepted scope and evidence required |
| Partly ordered | PARTIALLY_ORDERED | Convert eligible accepted remainder | Prevent duplicate quantity consumption |
| Fully ordered | FULLY_ORDERED | View linked orders | Fulfilment continues in order module |
| Expired | Unaccepted available scope past validity | Revise / reissue after review | Cannot accept stale scope automatically |
| Declined / lost | DECLINED or opportunity lost | Record reason; create a new pursuit if needed | Preserve offer and evidence |
| Superseded / withdrawn | SUPERSEDED or WITHDRAWN | View history | Block new acceptance; existing commitments remain |

### 13.3 Commercial change and revision policy

**QTN-002 [P0]:** Once issued, commercial content MUST be immutable. Price, quantity, scope, specification, dates, currency, tax basis, payment, and contractual terms changes create a new revision. Log noncommercial corrections under an explicit narrow policy.

**QTN-003 [P0]:** A revision MUST record its parent, change summary, source-requirement version, and fresh approval evaluation. Approvals apply to exact content/version, not the quote family indefinitely.

**QTN-004 [P0]:** Creating a replacement draft does not automatically withdraw a live offer. On issuing the replacement, default to superseding prior unaccepted scope in the same family. Preserve accepted commitments. A portal action from an old revision must fail clearly and point to the current available offer. Any policy permitting simultaneous options must make that explicit.

### 13.4 Expiry and acceptance races

**QTN-005 [P0]:** Check validity, document state, revision, approval, identity, and remaining scope inside the acceptance transaction. An expiry job only updates views/notifications. Define the deadline timezone and whether the boundary is inclusive; use a precise timestamp internally.

If a buyer accepted before expiry but order creation is temporarily delayed, retain the accepted commitment. Expiry of the unaccepted remainder must not erase valid prior acceptance. Late acceptance requires an authorized review and a new available offer or documented exception; never silently backdate it.

### 13.5 Line-level outcomes and quantities

Track offered quantity, cumulative accepted quantity, cumulative ordered quantity, and explicitly declined/withdrawn unaccepted quantity. Use append-only acceptance and allocation records rather than editing totals manually.

For fixed-quantity lines:

`0 <= ordered_active_qty <= accepted_active_qty <= offered_qty`

`0 <= accepted_active_qty + declined_or_withdrawn_unaccepted_qty <= offered_qty`

`unaccepted_available_qty = offered_qty - accepted_active_qty - declined_or_withdrawn_unaccepted_qty`

`0 <= ordered_active_qty + reserved_conversion_qty <= accepted_active_qty`

`accepted_unordered_available_qty = accepted_active_qty - ordered_active_qty - reserved_conversion_qty`

A pending external conversion holds `reserved_conversion_qty` until reconciled; it is unavailable for another conversion even before a remote order is confirmed.

Use consistent base UOM and decimal precision. A cancellation/reversal is a controlled record that re-evaluates what may be reused; it is not an unaudited decrement. Time-and-materials, recurring, and project agreements need value/term/milestone limits instead of pretending every commitment is a fixed quantity.

**QTN-006 [P0]:** Header outcomes MUST be derived from line/option outcomes, with documented precedence. A quote with 60 of 100 units accepted is partly accepted, even if those 60 are fully ordered. A quote with all 100 accepted but only 60 ordered is accepted and partly ordered.

## 14. Approvals, documents, and communication

### 14.1 Example approval matrix — configure for the business

The percentages below are examples, not researched industry norms.

| Trigger | Review owner | Release condition |
| --- | --- | --- |
| Effective discount above salesperson authority | Sales manager | Version-specific discount decision |
| Margin below approved floor or unknown material cost | Commercial / finance | Cost/margin exception with rationale |
| Long credit period or credit exposure | Finance / credit | Approved terms or order-release hold |
| Nonstandard contractual clause | Legal | Exact clause version approved |
| Custom specification / aggressive lead time | Engineering / operations | Feasibility and promised basis approved |
| High-value deal or unusual currency risk | Delegated senior approver | Threshold/currency-normalization policy satisfied |

**APR-001 [P0]:** Evaluate all applicable rules. Define serial versus parallel approvals, thresholds, company scope, delegates, absence handling, due dates, escalation, and rejected/rework outcomes. Missing approvers MUST block issue and alert the rule owner; never silently approve.

**APR-002 [P0]:** Enforce maker–checker separation for triggered exceptions. A user cannot approve their own request via another role or API path. Record approver identity, delegated authority, decision, time, content hash/version, policy version, and comments.

**APR-003 [P0]:** Relevant changes invalidate affected approvals and trigger re-evaluation. Approval of a 5% discount cannot authorize a later 15% discount or a different legal entity.

### 14.2 Customer-facing output

Separate transaction data from the PDF/HTML/email template. Include quote number and revision, customer references, parties, lines, totals, taxes, validity, delivery basis, payment, assumptions, exclusions, terms, and acceptance instructions.

**DOC-001 [P0]:** Preview and store the exact issued artifact with a hash and template version. Enforce a customer-safe field allowlist. Internal margin, supplier costs, private notes, and approval commentary MUST NOT appear in output, portal payloads, or customer-visible attachments.

**DOC-002 [P1]:** Support company branding, language, regional address/number/date formats, sections, technical appendices, and accessible output. A change in logo or template does not retroactively regenerate historical issued artifacts.

### 14.3 Sending and follow-up

**COM-001 [P0]:** Use a durable send queue with per-attempt tracking. Separate “issued” from “sent.” If sending fails, retain the issued version and expose retry/alternate-channel actions. Retrying MUST send the same artifact unless an explicit new revision was issued.

**COM-002 [P0]:** Record recipient, sender, channel, provider reference, artifact hash, attempt time, error, and available delivery events. Provider dedupe capabilities vary; target controlled retries and reconciliation rather than claiming end-to-end exactly-once delivery.

**COM-003 [P0]:** Link replies to the quotation family/revision and inquiry. Create follow-up tasks with owner and due date. Do not infer acceptance from a delivery receipt, open event, or vague “looks good” without scope and authority confirmation.

## 15. Acceptance and the handover to sales order

### 15.1 Acceptable evidence options

Depending on business policy, evidence can be a customer purchase order, authenticated portal acceptance, signed document, or salesperson-recorded acceptance supported by an email or other record. A signature alone does not resolve a different price, quantity, or scope in the buyer's PO.

**ACC-001 [P0]:** Record exact quote revision/hash, accepting account/contact or authorized representative, selected options, accepted line quantities or agreement scope, timestamp, evidence, and recorder. Record customer-requested deviations separately.

**ACC-002 [P0]:** Compare buyer acceptance/PO against the offer. Different payment terms, quantities, specification, shipping terms, or price must create a resolution task or new revision. Do not quietly turn a counteroffer into a matching order.

### 15.2 Order conversion

**ORD-001 [P0]:** Order creation MUST select accepted scope and preserve source line mappings, commercial snapshots, and acceptance references. Recheck authorization, party/company compatibility, remaining scope, pricing eligibility, and required customer/account data.

**ORD-002 [P0]:** Claim quantities and create the order atomically when modules share a database. For an external order system, create a durable pending conversion with an idempotency key, reserve the selected accepted scope, send via outbox, and reconcile acknowledgments. Do not release the claim on an unknown timeout until the remote outcome is resolved.

**ORD-003 [P0]:** A double click, job retry, or concurrent salesperson action MUST NOT create duplicate orders or consume more than accepted scope. Lock/update the relevant database records transactionally and enforce uniqueness for the conversion key.

**ORD-004 [P0]:** Separate “order created” from “order released.” Credit, supply, compliance, or incomplete-account holds can block execution without deleting the commercial commitment or falsely marking fulfilment complete.

### 15.3 What comes after the scoped module

| Owner module | Receives | Reports back |
| --- | --- | --- |
| Order management | Accepted commercial scope, customer PO, delivery/payment basis | Order IDs, line mappings, holds, amendments, cancellations |
| Inventory / fulfilment | Released stock requirements | Reservations, pick/dispatch, delivery, shortages |
| Manufacturing / procurement | Released make/buy requirements | Feasibility, expected dates, supplier/production progress |
| Projects / service delivery | Agreed scope, milestones, rates | Service acceptance, time/effort, milestones completed |
| Billing / finance | Billable order/delivery/milestone data | Invoices, credit notes, receivables, receipts |

Inquiry and quotation records should show this linked document flow. They should not implement their own inventory ledger or accounting ledger.

## 16. Enterprise requirements and architectural foundation

Enterprise readiness comes from controlled behavior under exceptions, changes, scale, and audit—not the number of fields or workflow statuses.

### 16.1 Minimum capability checklist

| Capability | Requirement and reason | Priority |
| --- | --- | --- |
| Data isolation | Tenant/company boundaries on every query and action; prevent cross-customer portal access | P0 |
| Authorization | Roles, account/territory scope, sensitive fields, delegated approval authority, SSO integration as required | P0 |
| Evidence and audit | Actor, time, change reason, before/after or event delta, document/revision, correlation ID | P0 |
| Immutability | Issued offer and acceptance evidence preserved; changes via versioned records | P0 |
| Financial correctness | Decimal calculations, currency precision, rounding, pricing explainability, approved overrides | P0 |
| Concurrency and idempotency | Prevent overwritten edits, duplicate events, duplicate orders, and over-consumed scope | P0 |
| Reliable integrations | Durable inbox/outbox, retries/backoff, error worklists, reconciliation, dead-letter review | P0 |
| Configuration governance | Versioned templates/rules, effective dates, previews, publishing rights, migrations | P0 |
| Privacy and attachments | Least-privilege access, encrypted transport/storage, safe upload processing, retention and deletion policy | P0 |
| Operations | Structured logs, metrics, traces, queue health, audit export, backups, restore validation | P0 |
| Localization | Currency/language/timezone; country-specific tax and document adapters for enabled markets | P0 for enabled markets |
| Service levels | Ownership, response clocks, escalation, holiday calendars, approved pause rules | P0 basic; P1 advanced |
| Search and worklists | Customer/reference/full-text search, permission-aware filtering, saved team queues | P0 |
| Scale | Pagination, indexes, async artifact generation and imports, large-line quote support | P0 baseline; P1 advanced |
| Advanced configuration | Complex pricing, CPQ, supplier comparison, detailed territory/capacity routing | P1/P2 by business |

Country-specific invoice mandates are usually owned by billing/localization. The quotation module needs the correct offer/tax basis and downstream data, rather than pretending a quote is a posted tax invoice.

### 16.2 Suggested module boundaries

| Module | Owns | Consumes |
| --- | --- | --- |
| Identity and access | Users, tenant/company membership, roles, scopes | Identity provider |
| Party / customer master | Parties, contacts, addresses, account status | CRM or external customer master |
| Communication integration | Channel authorization, inbound/outbound transport, provider events | Channel APIs |
| Sales intake | Inquiry, requirements, clarifications, ownership, response coverage | Communication and parties |
| Opportunity / pipeline | Pursuit, stages, probability, forecasts | Inquiries, quotations, order outcomes |
| Quotation | Offer families/revisions, scope/options, acceptances, document lifecycle | Pricing, feasibility, parties |
| Pricing / tax / estimation | Calculation rules, cost estimates, tax adapter contracts | Catalog, agreements, FX/tax sources |
| Approval | Version-specific requests, decisions, delegation | Quotation facts and policy |
| Document generation | Templates, rendering, issued artifacts | Sanitized offer snapshot |
| Order management | Orders, accepted scope allocations, release/holds | Accepted quotation or alternate order route |

**ARC-001 [P0]:** Begin with a modular application unless independent services solve a demonstrated requirement. Enforce module interfaces and table ownership even when deployed together. A modular monolith can retain transactional consistency without the operational cost of splitting every domain into a service.

**ARC-002 [P0]:** Keep channel-specific payloads out of core business entities. A canonical inbound record carries source identifiers and evidence pointers. A salesperson changing owner must not require knowledge of email or WhatsApp API details.

**ARC-003 [P0]:** Use optimistic version checks for edits and database transactions/locks or conditional updates for shared allocations. An in-memory lock is insufficient when multiple application instances process the same quote.

### 16.3 Events and integrations

Recommended events include `InquiryReceived`, `InquiryAssigned`, `ClarificationRequested`, `InquiryRequirementRevised`, `QuotationDraftCreated`, `QuotationApprovalRequested`, `QuotationIssued`, `QuotationTransmissionFailed`, `QuotationAccepted`, `QuotationRemainderExpired`, `OrderConversionRequested`, `OrderCreated`, and `OrderConversionFailed`.

Each event needs `event_id`, `event_type`, `schema_version`, `tenant_id`, `company_id`, `aggregate_id`, `aggregate_version`, `occurred_at`, `actor_ref`, `correlation_id`, and a minimal payload or secure reference. Store a business mutation and its outbox event in the same transaction. Consumers dedupe by event ID and tolerate duplicates; reordering must not overwrite newer revisions. Do not put secrets or unnecessary raw personal content in logs/events.

### 16.4 Operational targets to decide before launch

Set targets from expected line counts, daily inquiry volume, attachment sizes, user concurrency, and integration deadlines. Define p95 interactive response time, oldest unprocessed intake event, artifact-generation completion time, send failure age, recovery time objective, and recovery point objective. No numerical target here is claimed to be a researched enterprise standard.

## 17. Logical data model and cardinalities

This is a conceptual model, not final SQL. Use stable technical IDs; human-readable quote numbers can differ by legal entity and numbering policy.

| Entity | Key relationships / constraints |
| --- | --- |
| Party, Contact, Address | Party has many contacts/addresses; contact affiliations can be many-to-many if required |
| Conversation, Message, Attachment | Conversation has many messages; message has provider identity and evidence; attachments have independent access controls |
| Inquiry | Belongs to tenant; routed to company/queue; optionally party and opportunity; many requirement revisions |
| InquiryRequirement | Stable requirement identity; versioned specification, quantity, evidence and disposition |
| Clarification | Links inquiry/requirement and communication; question, owner, due date, resolution evidence |
| Opportunity | Party plus pursuit; many related inquiries/quotation families; one forecast value per defined basis |
| QuotationFamily | Groups revisions/options under a commercial pursuit; revisions are ordered and unique within family |
| QuotationRevision | Immutable after issue; many lines, terms, schedules, artifacts, and approval references |
| QuotationLine | Belongs to a revision; optional/alternative grouping, price/cost snapshots, execution basis |
| RequirementOfferMapping | Many-to-many inquiry requirement version ↔ quote revision line; scope/quantity mapping |
| PricingCalculation | Input snapshot, policy versions, breakdown, hash, calculation time |
| ApprovalRequest / ApprovalDecision | Exact content/version, required authority, decision and evidence |
| OfferArtifact / TransmissionAttempt | Artifact hash/template version; many send attempts referencing the same artifact |
| Acceptance / AcceptanceLine | Exact issued revision; scope and quantities; customer evidence; controlled reversals |
| OrderConversion / OrderAllocation | Idempotent handover; accepted line quantities reserved/consumed; remote status where applicable |
| TemplateVersion / RuleVersion | Published immutable configuration used by a record/calculation |
| AuditEvent / InboxEvent / OutboxEvent | Traceable business changes and reliable event processing |

### 17.1 Critical database constraints

**DAT-001 [P0]:** Use unique keys for tenant+source+external event identity, quote-family+revision number, event-consumer+event ID, and tenant+command idempotency key. Enforce tenant/company consistency in related records.

**DAT-002 [P0]:** Monetary and quantity fields MUST use defined decimal types and precision. Store UTC timestamps with an explicit deadline timezone where business interpretation requires it. Preserve original currency alongside any base-currency value and FX snapshot.

**DAT-003 [P0]:** Require expected version for edits. Validate quote allocation quantities transactionally; an application-only check before saving is vulnerable to concurrent conversion.

**DAT-004 [P0]:** Do not delete issued or accepted commercial history to fix a mistake. Apply explicit supersession, withdrawal, reversal, or cancellation records according to retention policy. Data retention must account for commercial record requirements and personal-data minimization.

### 17.2 Query indexes and search

Index tenant/company with owner/queue, work state, due date, party, customer RFQ reference, quote family, and validity. Index source identities for dedupe and source-line mappings for traceability. Use a permission-aware full-text index for long descriptions where needed. Treat reporting/search replicas as read models, not the authority for accepting a quote or consuming quantities.

## 18. Illustrative API and command contracts

These endpoint names are proposed contracts, not vendor API paths. A transaction must validate the same business rules whether invoked from UI, import, automation, or API.

| Command / endpoint | Purpose | Essential safeguards |
| --- | --- | --- |
| `POST /sales/inquiries` | Capture manual/canonical demand | Source idempotency, original evidence, tenant scope |
| `PATCH /sales/inquiries/{id}` | Update interpreted data | Expected version; preserve raw evidence |
| `POST /sales/inquiries/{id}/clarifications` | Ask or record a clarification | Recipient authorization; no automatic reply without send authorization |
| `POST /sales/inquiries/{id}/quotation-drafts` | Map selected requirements to an offer | Mapping version, selected scope, idempotency |
| `POST /sales/quotations/{revisionId}/calculate` | Explain price, tax, margin, and issues | Deterministic inputs; stale-context detection |
| `POST /sales/quotations/{revisionId}/approval-requests` | Request commercial approval | Exact content hash/version; valid approver resolution |
| `POST /sales/quotations/{revisionId}/issue` | Freeze and publish offer revision | All issue gates; artifact and approval consistency |
| `POST /sales/quotations/{revisionId}/transmissions` | Queue an issued artifact for sending | Approved recipient/channel; send-attempt dedupe |
| `POST /sales/quotations/{revisionId}/revisions` | Create a changed draft | Parent link; diff; policy for old issued scope |
| `POST /sales/quotations/{revisionId}/acceptances` | Record customer commitment | Validity/revision/scope/identity check within transaction |
| `POST /sales/quotations/{revisionId}/order-conversions` | Turn accepted scope into order | Atomic allocation or durable external handover |
| `POST /sales/quotations/{revisionId}/withdrawals` | Withdraw available unaccepted scope | Reason; preserve existing acceptances/orders |

Suggested response behavior: permission failures, version conflicts, duplicate payload mismatch, unavailable revision, and missing commercial fields must be distinguishable. Return structured issues such as `code`, `field_path`, `line_id`, `severity`, `blocked_action`, and `suggested_next_action`. A repeated key with a different payload must fail rather than silently reuse an unrelated result.

## 19. Machine-readable configuration and payload examples

The following examples are coherent starting points, not schemas copied from an ERP. Implement them through your selected configuration and validation system.

### 19.1 Inquiry template example

```yaml
template_id: standard-goods-inquiry
version: 1
state: PUBLISHED
company_scope: [COMPANY-IN-01]
effective_from: 2026-10-19
fallback_for_unclassified_intake: true
fields:
  - key: original_request
    type: text
    required_at: [RECEIPT]
  - key: reply_route
    type: contact_route
    required_at: [SEND_CLARIFICATION, ISSUE_FIRM]
  - key: items
    type: requirement_lines
    minimum_at:
      RECEIPT: 0
      CREATE_QUOTATION_DRAFT: 1
line_fields:
  - key: confirmed_item_or_specification
    type: item_or_specification_ref
    required_at: [ISSUE_FIRM]
  - key: quantity
    type: decimal
    nullable_at: [RECEIPT, CREATE_QUOTATION_DRAFT]
    required_at: [ISSUE_FIRM]
    validation: positive_when_present
  - key: uom
    type: uom_ref
    required_at: [ISSUE_FIRM]
rules:
  - id: manufactured-part-drawing
    condition:
      field: requirement_kind
      equals: MANUFACTURED_PART
    require:
      fields: [drawing_reference, drawing_revision]
      at: ENGINEERING_APPROVAL
```

This profile is for fixed-quantity goods. Service and rate-agreement templates use their own pricing/measurement basis and gates.

### 19.2 Partial inquiry example

```json
{
  "inquiry_id": "INQ-2026-0042",
  "tenant_id": "TENANT-01",
  "company_id": "COMPANY-IN-01",
  "source_channel": "EMAIL",
  "source_system": "sales-mailbox",
  "external_message_id": "example-message-0042",
  "received_at": "2026-10-19T07:30:00Z",
  "original_request": "Need control units urgently for Pune. Please quote.",
  "provisional_party": {"name": "Example Manufacturing"},
  "reply_route": "buyer@example.invalid",
  "work_state": "TRIAGE",
  "queue_id": "industrial-sales",
  "template_id": "standard-goods-inquiry",
  "template_version": 1,
  "requirements": [{
    "requirement_id": "REQ-0042-01",
    "version": 1,
    "original_description": "control units",
    "item_id": null,
    "quantity": null,
    "uom": null,
    "requested_delivery_at": null,
    "missing_fields": ["specification", "quantity", "uom", "delivery_deadline"]
  }]
}
```

### 19.3 Draft-generation command after clarification

```json
{
  "command": "CreateQuotationFromInquiry",
  "idempotency_key": "example-inq0042-optionA-create1",
  "inquiry_id": "INQ-2026-0042",
  "expected_inquiry_version": 4,
  "offer_basis": "FIRM",
  "currency": "INR",
  "mapping_policy_version": "standard-goods-v1",
  "selection": [{
    "requirement_id": "REQ-0042-01",
    "requirement_version": 2,
    "item_id": "CU-20",
    "quantity": "100.000",
    "uom": "EA"
  }],
  "result_document_state": "DRAFT"
}
```

The client cannot force approval or supply trusted totals in this command. The server resolves prices, verifies item mapping, and returns the draft plus issues and required approvals.

### 19.4 Normative command behavior

```text
Given a current inquiry and an authorized selection:
  validate tenant/company and expected version
  check idempotency key and request payload hash
  resolve source requirement versions
  construct a draft with explicit source mappings
  calculate and return issues; do not auto-issue
  commit draft + audit + outbox together
On repeated identical command:
  return the previously committed draft
On stale inquiry version or mismatched repeated payload:
  return a conflict; do not create a second draft
```

## 20. Worked business scenarios

### 20.1 Incomplete inquiry becomes a controlled offer

1. **Receive:** “Need control units urgently for Pune.” Intake preserves email and attachments, creates INQ-2026-0042, and routes it to industrial sales. No fake SKU or quantity is inserted.
2. **Clarify:** Sales asks model/application, quantity, required date, destination, and whether installation is needed. Inquiry becomes AWAITING_CUSTOMER with a next-contact date.
3. **Confirm scope:** Buyer confirms 100 CU-20 units, Pune, required by 30 November 2026, supply only. Sales verifies specification and records the reply as evidence.
4. **Prepare:** Assisted conversion produces quote Q-0042 revision 1. Pricing matches the illustrative calculation in section 12. No quantity-tier discount is assumed.
5. **Approve:** The 10% discount exceeds the example salesperson authority of 5%, so a manager approves this version. Supply review confirms the stated delivery basis.
6. **Issue and send:** The system freezes revision 1, stores its PDF/hash, and queues delivery. A provider error creates a send failure task; retry uses the same artifact.
7. **Partial acceptance:** The buyer accepts 60 units without changing the flat unit rate or other terms. The system records an acceptance for 60 and leaves 40 available until the stated deadline. The example offer explicitly permits partial releases at the flat unit price and ₹2,000 freight per shipment; totals are recalculated for the selected scope.
8. **Order:** Converting 60 units creates one linked sales order: ₹60,480 net goods + ₹2,000 freight + ₹11,246.40 hypothetical tax = ₹73,726.40. A repeated click returns the same conversion result. The quote is partly accepted and partly ordered relative to the full offered 100 units.
9. **Remainder:** Another 40 may be accepted while valid, or closed/expired with a reason. The inquiry can already be closed as fully responded; the opportunity's outcome follows its separate deal policy.

### 20.2 Ten requested lines; only seven are clear

Quote the seven with explicit exclusions and pending references. Keep the other three in SCOPING/AWAITING_CUSTOMER or close them with an approved no-bid decision. Do not mark ten lines commercially covered because one PDF was generated. If alternatives cover the same seven requirements, do not double the inquiry's requested volume.

### 20.3 Custom manufacture with missing costs

Capture the drawing and its revision; request engineering feasibility and a cost estimate. Procurement obtains supplier prices if needed. Sales may issue an explicitly budgetary estimate under policy. A firm version requires agreed tolerances, tooling/inspection scope, cost-risk disposition, and delivery basis. Changes to the drawing trigger impact analysis and reapproval of affected commercial content.

### 20.4 Service engagement with uncertain effort

Ask for deliverables, exclusions, dependencies, site, and acceptance criteria. Choose a fixed-fee scope or a time-and-materials agreement with rates, assumptions, and an authorization cap. Acceptance is measured by the agreement's scope/value/term; downstream timesheets and milestones must not be forced into the fixed-goods quantity model.

### 20.5 Customer PO differs from the quotation

The quote says 30-day credit; the PO says 90 days. Record the PO as evidence and flag the mismatch. Obtain customer clarification and finance approval or issue a revised offer. Do not generate an apparently matching executable order by silently adopting the PO terms.

## 21. Worklists, reports, and KPI definitions

### 21.1 Daily screens

| Screen | What the user should see and do |
| --- | --- |
| Intake queue | New, unmatched, duplicate candidates, aging, routing errors |
| My inquiries | Owner, due date, next action, missing-data blockers, customer waiting |
| Inquiry detail | Original evidence, interpreted requirements, clarifications, specialists, quote coverage |
| Quote editor | Lines/options, calculation explanation, cost/margin access, delivery, terms, completeness |
| Approval inbox | Version diff, trigger reasons, commercial impact, approve/reject/rework |
| Quote register | Available revision, customer decision, validity, transmission health, order progress |
| Customer view | Safe offer, choices, assumptions, change request, acceptance with clear revision |
| Order handover queue | Accepted-unordered scope, pending conversions, holds, failures, reconciliation |
| Configuration workspace | Versioned templates, rule preview, publish/retire, test examples |

### 21.2 Metrics with explicit denominators

| Metric | Definition / caution |
| --- | --- |
| First human response time | Business-time elapsed from receipt to first meaningful human reply; automated acknowledgment excluded |
| Assignment delay | Receipt to accountable owner/queue claim; show unclaimed aging separately |
| Inquiry-to-first-offer time | Receipt to first issued quote; split total time into customer wait and internal work |
| Quote preparation time | Quote-draft creation to issue; split approval and specialist waiting |
| Inquiry response coverage | Unique requirement versions addressed / in-scope requirement versions, or a clearly named value/quantity basis |
| Inquiry-to-quote rate | Unique eligible inquiries with an issued quote / eligible inquiry cohort; exclude spam/duplicates consistently |
| Quote win rate | Won quote families / decided eligible quote families; exclude superseded revisions from the denominator |
| Opportunity win rate | Won opportunities / decided opportunities; do not substitute quotation count |
| Approval turnaround | Request to required decisions; track overdue and rework loops |
| Acceptance-to-order delay | Valid acceptance to confirmed order creation; expose integration-pending cases |
| Acceptance conversion | Ordered accepted value or quantity / accepted eligible value or quantity, with consistent basis |
| Expiry / no-response | Unaccepted scope expiring or closed with no response; distinguish from explicit buyer rejection |
| Margin leakage | Approved margin versus final ordered margin under the same cost basis; explain changes |
| Data quality | Duplicate rate, unresolved item matches, missing reply routes, overrides, stale costs |

**RPT-001 [P0]:** Reports MUST define cohort dates, currency normalization, exclusions, scope basis, and revision treatment. Alternative quotes and multiple revisions must not inflate pipeline. Forecast against an opportunity's chosen commercial basis, not the sum of every draft option.

## 22. Implementation roadmap and release gates

### 22.1 Phase 0 — define the first business profile

Choose the initial industry and sales motion, one legal entity/country baseline, the initial channel, who owns customer/item/price masters, and where orders go. Walk through ten representative real requests, including an incomplete request, custom item, partial quote, revised quote, and PO mismatch.

**Outputs:** approved glossary, data dictionary, state model, pricing/approval policy, template examples, role matrix, and integration ownership. **Exit:** business owners can explain every example's outcome without contradictory rules.

### 22.2 Phase 1 — inquiry foundation and assisted draft preparation

Build manual intake plus one monitored email/import path, original evidence, party matching, ownership/queues, basic SLA tasks, requirement lines, clarification history, versioned intake profiles, draft quote mapping, and base pricing.

**Exit:** incomplete demand can be captured and resolved; selected requirements create repeatable drafts; permissions and duplicate handling pass tests. **Deployment scope:** internal preparation/pilot only until Phase 2 commercial controls are complete.

### 22.3 Phase 2 — controlled quotation and order handover

Add calculation trace, approval rules, immutable issued versions, customer-safe artifacts, reliable sending, revision/supersession, exact acceptance evidence, validity checks, partial acceptance/allocation, and idempotent order handover.

**Exit:** the complete P0 acceptance suite passes; users can audit inquiry → requirement → offer revision → acceptance → order line. This phase plus the applicable P0 platform controls forms the first production candidate.

### 22.4 Phase 3 — operational scale

Add richer assignment and calendars, reusable commercial/output templates, manager dashboards, import/reconciliation tooling, portal self-service, localization for newly enabled markets, and performance tuning against measured demand. Harden support runbooks and upgrade/migration procedures.

**Exit:** pilot operational metrics meet agreed targets, incidents are diagnosable, and configuration changes can be safely published and rolled back for future use.

### 22.5 Phase 4 — selective extensions

Add additional channels, customer-specific EDI mappings, complex product configuration, engineered costing, supplier comparisons, recurring/project agreements, tender packaging, and AI-assisted extraction only where the first customer profile needs them.

**Exit:** each extension has explicit ownership, exceptions, reconciliation, permission rules, and tests. Automated issue remains restricted to approved deterministic scenarios.

### 22.6 Production go-live checklist

Before enabling real offers/orders, validate the configured price/tax/terms masters, account/item migration, role isolation, approval authority, customer-safe documents, duplicate/retry behavior, backup restore, audit retrieval, and support runbooks. Run a representative business pilot and record sign-off. A happy-path demo alone is insufficient.

Do not attach calendar promises to these phases before estimating the chosen integrations and industry profile. The sequence gives dependencies and release criteria, not an invented delivery schedule.

## 23. Acceptance tests and feature definition of done

Each feature requires meaningful unit tests for rules, integration tests for database and module boundaries, and UI end-to-end coverage for critical sales journeys. Use isolated test accounts/data and provider sandboxes or controlled adapters; real production messages, customer documents, and orders are not disposable test fixtures.

| Test ID | Given / when | Required result | Main level |
| --- | --- | --- | --- |
| T01 | Intake lacks SKU/quantity | Saves with explicit missing fields and owner/queue | Integration + UI |
| T02 | Same email/webhook event is retried | One message and one appropriate inquiry link | Integration |
| T03 | Clarification arrives on an existing request | Appends to the request; retains source evidence | Integration + UI |
| T04 | Same buyer sends an unrelated new request | Separate inquiry; no domain-only auto-merge | Integration |
| T05 | Unauthorized tenant/account accesses record, attachment, export, or portal URL | Access denied; no metadata/content leak | Security integration |
| T06 | Routing matches no eligible person | Accountable fallback queue and escalation | Unit + integration |
| T07 | Conditional form field is hidden in UI but required at firm issue | Server blocks issue with field-specific error | Integration |
| T08 | Template version 2 is published | Existing version-1 inquiry stays interpretable; explicit migration only | Integration |
| T09 | Seven of ten requirements are quoteable | Draft maps seven; remaining three are visible and unresolved | Integration + UI |
| T10 | Same draft conversion command is repeated | Same result; no extra draft | Integration |
| T11 | Same idempotency key carries different payload | Conflict; original result preserved | Integration |
| T12 | Multiple eligible pricing rules overlap | Declared precedence/stacking gives explained deterministic result | Unit |
| T13 | Decimal quantity, currency precision, tax-inclusive/exclusive or document discount changes | Correct declared calculation/rounding; no floating-point drift | Unit + integration |
| T14 | Worked example in section 12 is calculated | Total ₹121,304; gross margin approximately 20.23% under its assumptions | Unit |
| T15 | Discount/terms violate policy | Correct approvers; self-approval and missing-approver bypass blocked | Unit + integration |
| T16 | Approved commercial content changes | Approval invalidation and re-evaluation | Integration |
| T17 | Master price/address/template changes after issue | Original artifact/content remains unchanged | Integration |
| T18 | Customer output is generated | No cost/margin/private notes in PDF, HTML, attachments, or payload | Integration + visual review |
| T19 | Initial send fails and is retried | Visible attempt history; same issued artifact; controlled duplicate behavior | Integration |
| T20 | Issued quote is revised | Parent/diff retained; previous unaccepted scope superseded at replacement issue | Integration + UI |
| T21 | Buyer accepts superseded or expired revision | Transaction rejects; current offer or review path shown | Integration + UI |
| T22 | Buyer accepted before expiry; order job runs after expiry | Valid acceptance retained; eligible order handover continues | Integration |
| T23 | Buyer PO differs from offered terms | Exception task; no silent commercial substitution | Integration + UI |
| T24 | 60 of 100 flat-price units accepted and ordered | 40 remain available while valid; quantities and labels remain consistent | Integration + UI |
| T25 | Two users convert the same accepted remainder concurrently | No duplicate consumption or excess order quantity | Concurrency integration |
| T26 | External order creation times out after possible remote success | Pending/reconciliation state; no blind resubmission or claim release | Integration |
| T27 | Buyer chooses one of two alternatives | Exactly the permitted selected configuration is totaled and ordered | Unit + integration |
| T28 | Quantity falls below tier-price threshold | Explicit reprice/approval/agreement behavior; no stale tier rate | Unit + integration |
| T29 | Order is canceled/reversed | Audited allocation adjustment; no automatic unauthorized reuse | Integration |
| T30 | Inquiry is closed/reopened or partly quoted | Coverage and closure reasons preserved; no automatic opportunity win | Integration |
| T31 | Business calendar, pause, or deadline timezone changes | Predictable SLA and acceptance cutoff; original policy retained | Unit + integration |
| T32 | Event replay occurs out of order | No overwrite of newer revision or duplicate business mutation | Integration |
| T33 | Budgetary offer goes to order | Blocked until firm revalidation or explicitly approved alternate route | Integration |
| T34 | Search/report includes alternatives and revisions | Correct permissions, unique demand, quote-family denominators | Integration |
| T35 | Large quote/import, failed worker, and restore are exercised | Agreed performance/recovery targets; recoverable work with audit | Performance + operations |
| T36 | Service/T&M offer uses value/term cap | Acceptance/order limits follow service agreement basis | Unit + integration |

**QA-001 [P0]:** A feature is complete only when its rules, permissions, negative cases, integration failures, and documentation are covered by appropriate passing tests. CI must enforce the selected required checks. Tests should validate business outcomes, not merely mirror implementation code.

## 24. Decisions you should make before coding

| Decision | Recommended starting point | Why / when to change |
| --- | --- | --- |
| First customer profile | One B2B sales motion, such as standard goods plus simple services | Prevents incompatible industry requirements from becoming one huge form |
| Inquiry versus lead | Inquiry is a request; party/lead identifies the buyer | Existing customers have new requests too |
| Opportunity mandatory? | Optional for simple sales; use for managed deals | Keeps transactional sales quick and forecasts meaningful |
| Customer creation point | Provisional party initially; approved customer/account by order | Avoids pollution of accounting masters |
| Allowed shortcuts | Permit direct quote/order with documented source and checks | Not every sale starts with a new lead |
| Initial channels | Manual entry plus one controlled email/form/import route | Proves business workflow before channel proliferation |
| Partial requests | Save immediately; use stage-specific blockers | Avoids fake data and lost inquiries |
| Configurability | Stable core plus typed, versioned profiles | Customization without breaking history |
| Price authority | Deterministic calculation; explicit overrides and approval limits | Prevents unexplained commercial commitments |
| Quote revisions | Immutable issued revisions; one current available revision per family by default | Customer and ERP retain the same offer |
| Partial acceptance / ordering | Build quantity and allocation model from the beginning | Retrofitting it is expensive and error-prone |
| Quote inventory reservation | Off by default; optional explicit timed reservation | Prevents speculative demand from blocking all stock |
| Order price policy | Preserve accepted commercial basis; recheck changed-scope eligibility | Operational changes must not silently rewrite a commitment |
| Acceptance evidence | Exact revision plus authorized scope and evidence | A “won” flag is insufficient |
| Approval controls | Maker–checker for exceptions, version-bound decisions | Controls must hold through UI and API |
| Technical deployment | Modular application with explicit domain ownership | Split services only when justified by real requirements |
| Tax and localization | Country adapters for the markets actually enabled | Avoids hardcoding one regime into the core |
| Automation boundary | Assisted draft creation first | Reliable data and exception policy precede automatic issue |
| SLAs / performance / retention | Agree measurable targets with the first operating team | They depend on volume, workflow, and obligations |

Recommended first production outcome: **an incomplete request can become a correctly priced, approved, versioned offer, then a traceable order, without losing evidence or creating duplicates.** Broader CRM campaigns, advanced CPQ, tendering, and omnichannel automation can expand from that foundation.

## 25. Research method, evidence limits, and validation plan

This research uses official vendor documentation and official SAP learning material. It combines process descriptions, configuration guidance, and documented transaction behavior. It does not rely on reseller comparisons or claim to have tested any vendor installation.

- SAP core examples are scoped to S/4HANA Sales / Cloud Public Edition material. Exact app availability and configuration differ by deployment.
- JD Edwards sources are EnterpriseOne 9.2 Sales Order Management, CRM for Sales, and Data Interface documentation. Procurement quote orders and JD Edwards World are not used as evidence for its sales-quote lifecycle.
- ERPNext documentation is rolling. The specific CRM roadmap notice is explicitly scoped to what the current documentation says about develop/version 17.
- Odoo evidence is 19.0 official documentation. Features may require installed applications, settings, or edition-specific capabilities; this report does not certify licensing/edition availability.
- Dynamics sources are Dynamics 365 Sales documentation; no claim is made that Business Central or Finance/Supply Chain uses the same exact record model.
- SAP Help pages S05/S06 and Odoo pages S29–S32 were reviewed through indexed official documentation excerpts; complete page bodies were unavailable in this review. Claims from them are limited to the features stated in those excerpts. The broader design is proposed, rather than inferred as a complete native SAP workflow.
- No finding that a product has a configurable feature proves that your proposed profile is preconfigured, license-included, or enabled by default.

Before locking the implementation, validate ten real customer examples with sales, finance, and operations. In the selected vendor reference environment, if available, demonstrate partial reference, revisions, missing-field behavior, price preservation, and approval reset. Confirm the first market's document/tax rules and integration contracts with the responsible business owners. Preserve unresolved choices as product decisions, not hidden assumptions.

### 25.1 Deliverable validation

Validated the Markdown metadata, YAML/JSON examples, requirement/source identifiers, worked arithmetic, HTML section links, self-contained assets, and JavaScript syntax. Browser rendering was unavailable in the authoring environment, so desktop/mobile visual layout and browser execution of the interactive controls were not verified. The HTML includes all report content without requiring external assets or network access.

## 26. Official source register

All sources were reviewed on **19 October 2026**. “Full” means readable official page content; “indexed” means the limited access described in section 25. The register identifies which vendor fact each source supports. The requirements elsewhere in this document are the proposed product specification.

| ID | Product / official page | Access | Evidence used |
| --- | --- | --- | --- |
| S01 | [SAP — Using Presales Documents](https://learning.sap.com/courses/exploring-sap-s-4hana-sales-essentials/using-presales-documents_b23b2418-88db-4494-99d1-bda90e0af1f1) | Full | Optional inquiry/quotation path and response context |
| S02 | [SAP — Understanding Sales Quotation Processing](https://learning.sap.com/courses/implementing-sap-s-4hana-cloud-public-edition-sales-fundamental-business-processes/understanding-sales-quotation-process_c189a9c0-aa19-4643-843b-69f9f56ad5de) | Full | Inquiry reference, customer outcomes, partial reference |
| S03 | [SAP — Analyzing Copying Control](https://learning.sap.com/courses/fundamental-customizing-in-sap-s-4hana-sales/analyzing-the-copying-control-for-sales-documents_c9bc5197-f6df-4793-b0a8-000fcbb1684b) | Full | Document flow and configurable completion rules |
| S04 | [SAP — Configuring Copying Control](https://learning.sap.com/courses/fundamental-customizing-in-sap-s-4hana-sales/configuring-copying-control-for-sales-documents_b0eacb8d-5f53-4619-aaca-65383f719acd) | Full | Header/item/schedule transfer and eligibility checks |
| S05 | [SAP Help — List Incomplete Sales Documents](https://help.sap.com/docs/SAP_S4HANA_CLOUD/a376cd9ea00d476b96f18dea1247e6a5/cc55a1dc97754286be702ed5d3c89a6b.html) | Indexed | Worklist for incomplete inquiries and quotations |
| S06 | [SAP Help — Manage Sales Document Workflows](https://help.sap.com/docs/SAP_S4HANA_CLOUD/a376cd9ea00d476b96f18dea1247e6a5/82db0a77a4ee48cda01f873d5a416bd2.html) | Indexed | Release, reject, and rework approval actions |
| S07 | [Oracle — Understanding Quote Orders](https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoaso/understanding-quote-orders.html) | Full | Quote orders, conversion, configurable quantity effects |
| S08 | [Oracle — Understanding Quotes and Sales Orders](https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-quotes-and-sales-orders.html) | Full | Configured opportunity-to-quote/order actions |
| S09 | [Oracle — Understanding Qualification](https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-qualification.html) | Full | Qualification scripts, questions, and scoring |
| S10 | [Oracle — Understanding Inbound Requests for Quotes](https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoadi/understanding-inbound-requests-for-quotes.html) | Full | EDI customer RFQ intake into quote orders |
| S11 | [Oracle — Understanding Additional Order Entry](https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoaso/understanding-additional-order-entry.html) | Full | Whole/partial conversion and inventory context |
| S12 | [Oracle — Sales Order Entry Process Options](https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoaso/process.html) | Full | Repricing, quote releases, price-field controls |
| S13 | [Oracle — Understanding Proposal Generation](https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-proposal-generation.html) | Full | Proposal output from quotes/orders |
| S14 | [Oracle — Understanding Proposal Template](https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-proposal-template.html) | Full | Activated, dated templates and transaction tags |
| S15 | [ERPNext — Lead](https://docs.frappe.io/erpnext/lead) | Full | Lead identity, ownership, communication, conversion |
| S16 | [ERPNext — Opportunity](https://docs.frappe.io/erpnext/opportunity) | Full | Customer/lead opportunities and quote preparation |
| S17 | [ERPNext — Quotation](https://docs.frappe.io/erpnext/quotation) | Full | Quotation parties, mapping, lifecycle, alternatives |
| S18 | [ERPNext — Automate Lead Creation](https://docs.frappe.io/erpnext/automate_lead_capturing) | Full | Email, web forms, ecommerce, and import routes |
| S19 | [ERPNext — Assignment Rule](https://docs.frappe.io/erpnext/assignment-rule) | Full | Round-robin, load-balancing, field-based assignment |
| S20 | [ERPNext — Customize Form](https://docs.frappe.io/erpnext/customize-form) | Full | Custom fields and form properties |
| S21 | [ERPNext — Workflows](https://docs.frappe.io/erpnext/workflows) | Full | Multilevel quotation approval example |
| S22 | [ERPNext — Pricing Rule](https://docs.frappe.io/erpnext/pricing-rule) | Full | Conditional rate, discount, margin, product rules |
| S23 | [ERPNext — Request for Quotation](https://docs.frappe.io/erpnext/request-for-quotation) | Full | Procurement RFQ distinction |
| S24 | [ERPNext — CRM Settings](https://docs.frappe.io/erpnext/crm_settings) | Full | Configurable validity and communication carry-forward |
| S25 | [ERPNext — Introduction to Selling Module](https://docs.frappe.io/erpnext/selling) | Full | Connected selling cycle and process variations |
| S26 | [ERPNext — Introduction to CRM](https://docs.frappe.io/erpnext/CRM) | Full | Object distinctions, optional paths, scoped roadmap notice |
| S27 | [Microsoft — Create or Edit Quotes](https://learn.microsoft.com/en-us/dynamics365/sales/create-edit-quote-sales) | Full | Draft/active lifecycle and opportunity mapping |
| S28 | [Microsoft — Manage Quote, Order, and Invoice](https://learn.microsoft.com/en-us/dynamics365/sales/sales-transactions) | Full | Activation, read-only content, revised drafts |
| S29 | [Odoo 19 — Create and Send Quotations](https://www.odoo.com/documentation/19.0/applications/sales/crm/acquire_leads/send_quotes.html) | Indexed | Opportunity-origin quotes, preview, email, history |
| S30 | [Odoo 19 — Create Quotations](https://www.odoo.com/documentation/19.0/applications/sales/sales/sales_quotations/create_quotations.html) | Indexed | Reusable offers, signature/payment confirmation settings |
| S31 | [Odoo 19 — PDF Quote Builder](https://www.odoo.com/documentation/19.0/applications/sales/sales/sales_quotations/pdf_quote_builder.html) | Indexed | Branded output combined with transaction data |
| S32 | [Odoo 19 — Optional Products](https://www.odoo.com/documentation/19.0/applications/sales/sales/sales_quotations/optional_products.html) | Indexed | Optional products in offers |

[S01]: https://learning.sap.com/courses/exploring-sap-s-4hana-sales-essentials/using-presales-documents_b23b2418-88db-4494-99d1-bda90e0af1f1
[S02]: https://learning.sap.com/courses/implementing-sap-s-4hana-cloud-public-edition-sales-fundamental-business-processes/understanding-sales-quotation-process_c189a9c0-aa19-4643-843b-69f9f56ad5de
[S03]: https://learning.sap.com/courses/fundamental-customizing-in-sap-s-4hana-sales/analyzing-the-copying-control-for-sales-documents_c9bc5197-f6df-4793-b0a8-000fcbb1684b
[S04]: https://learning.sap.com/courses/fundamental-customizing-in-sap-s-4hana-sales/configuring-copying-control-for-sales-documents_b0eacb8d-5f53-4619-aaca-65383f719acd
[S05]: https://help.sap.com/docs/SAP_S4HANA_CLOUD/a376cd9ea00d476b96f18dea1247e6a5/cc55a1dc97754286be702ed5d3c89a6b.html
[S06]: https://help.sap.com/docs/SAP_S4HANA_CLOUD/a376cd9ea00d476b96f18dea1247e6a5/82db0a77a4ee48cda01f873d5a416bd2.html
[S07]: https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoaso/understanding-quote-orders.html
[S08]: https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-quotes-and-sales-orders.html
[S09]: https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-qualification.html
[S10]: https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoadi/understanding-inbound-requests-for-quotes.html
[S11]: https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoaso/understanding-additional-order-entry.html
[S12]: https://docs.oracle.com/en/applications/jd-edwards/supply-chain-manufacturing/9.2/eoaso/process.html
[S13]: https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-proposal-generation.html
[S14]: https://docs.oracle.com/en/applications/jd-edwards/customer-relationship/9.2/eoasf/understanding-proposal-template.html
[S15]: https://docs.frappe.io/erpnext/lead
[S16]: https://docs.frappe.io/erpnext/opportunity
[S17]: https://docs.frappe.io/erpnext/quotation
[S18]: https://docs.frappe.io/erpnext/automate_lead_capturing
[S19]: https://docs.frappe.io/erpnext/assignment-rule
[S20]: https://docs.frappe.io/erpnext/customize-form
[S21]: https://docs.frappe.io/erpnext/workflows
[S22]: https://docs.frappe.io/erpnext/pricing-rule
[S23]: https://docs.frappe.io/erpnext/request-for-quotation
[S24]: https://docs.frappe.io/erpnext/crm_settings
[S25]: https://docs.frappe.io/erpnext/selling
[S26]: https://docs.frappe.io/erpnext/CRM
[S27]: https://learn.microsoft.com/en-us/dynamics365/sales/create-edit-quote-sales
[S28]: https://learn.microsoft.com/en-us/dynamics365/sales/sales-transactions
[S29]: https://www.odoo.com/documentation/19.0/applications/sales/crm/acquire_leads/send_quotes.html
[S30]: https://www.odoo.com/documentation/19.0/applications/sales/sales/sales_quotations/create_quotations.html
[S31]: https://www.odoo.com/documentation/19.0/applications/sales/sales/sales_quotations/pdf_quote_builder.html
[S32]: https://www.odoo.com/documentation/19.0/applications/sales/sales/sales_quotations/optional_products.html
