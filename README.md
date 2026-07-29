# ZVX_08 — Sample Request RAP Application

A complete SAP RAP (RESTful ABAP Programming Model) build for roll 08 (ZVX_08_*): CDS entities, projections, metadata extensions, behaviour definitions, business logic, OData service exposure for a Fiori Elements app, and a classic ALV report for console testing.

---

## Architecture Overview

```
Database Table  →  Root CDS View  →  Projection CDS View  →  Metadata Extension  →  Service Binding  →  Fiori UI
                         ↑
            Behavior Definition + Implementation Class
            (business logic lives here)
```

Each layer only knows about its own concern — the table doesn't know about UI, the root CDS doesn't know which app consumes it, the projection doesn't know how it's rendered, the metadata extension doesn't know the business rules, and the behaviour implementation doesn't know about Fiori at all.

---

## Step 1 — Table `ZVX_08_SMPL_REQ`

Build this in ADT (New → Other ABAP Repository Object → Database Table) or SE11.

| Field                 | Data Element         | Key |
|---|---:|:---:|
| CLIENT                | MANDT               | ✅ |
| REQUEST_UUID          | SYSUUID_X16         | ✅ |
| REQUEST_NO            | NUMC(10)            |    |
| CUSTOMER              | KUNNR               |    |
| MATERIAL              | MATNR               |    |
| PLANT                 | WERKS_D             |    |
| QUANTITY              | QUAN(13,3)          |    |
| UOM                   | MEINS               |    |
| REQ_DATE              | DATS                |    |
| REQ_STATUS            | CHAR(2)             |    |
| REJECT_REASON         | CHAR(60)            |    |
| APPROVED_BY           | SYUNAME             |    |
| APPROVED_ON           | DATS                |    |
| CREATED_BY            | SYUNAME             |    |
| CREATED_AT            | TIMESTAMPL          |    |
| LAST_CHANGED_BY       | SYUNAME             |    |
| LAST_CHANGED_AT       | TIMESTAMPL          |    |
| LOCAL_LAST_CHANGED_AT | TIMESTAMPL          |    |

Or paste into the SE11/ADT source editor (textual DDIC) for convenience:

```abap
@EndUserText.label : 'ZVX08 Sample Request'
@AbapCatalog.tableCategory : #TRANSPARENT
define table zvx_08_smpl_req {
  key client            : mandt not null;
  key request_uuid      : sysuuid_x16 not null;
  request_no            : numc10;
  customer              : kunnr;
  material              : matnr;
  plant                 : werks_d;
  @Semantics.quantity.unitOfMeasure : 'zvx_08_smpl_req.uom'
  quantity              : abap.quan(13,3);
  uom                   : meins;
  req_date              : dats;
  req_status            : abap.char(2);
  reject_reason         : abap.char(60);
  approved_by           : syuname;
  approved_on           : dats;
  created_by            : syuname;
  created_at            : timestampl;
  last_changed_by       : syuname;
  last_changed_at       : timestampl;
  local_last_changed_at : timestampl;
}
```

Important activation step: after activation, open the table's Currency/Quantity settings (SE11 → Table → Goto → Currency/Quantity fields) and set Reference field for QUANTITY = UOM. If you skip this, QUANTITY will usually fail activation.

Defense-ready one-liner: REQUEST_UUID is the technical key RAP needs internally; REQUEST_NO is the friendly number shown to users — they are separate to give RAP stable technical identifiers and readable numbers for UI.

---

## Step 2 — Message class `ZVX_08_MSG` (SE91)

Create a message class `ZVX_08_MSG` and add these messages (001..010). Use `&` placeholders for parameters.

```
001 | Material &1 not found (MATNR=&1)
002 | Material &1 is not maintained for plant &2
003 | Customer &1 not found
004 | Customer &1 is blocked (deletion/order block)
005 | Quantity must be greater than 0
006 | Quantity &1 exceeds allowed maximum &2
007 | Monthly cap reached for customer &1 in month &2
008 | Request number generation failed
009 | Approve only allowed when status = 01 (Requested)
010 | Reject reason must be at least 10 characters
```

Always raise messages from this class (via the RAP response object or `io_response->add_message`) — do not hard‑code UI text.

---

## Step 3 — Utility class `ZCL_VX_08_SAMPLE_RULES` (SE24 / ADT)

This single class contains variant constants and helper methods used by RAP and the ALV report. Create it as public, final and static (class methods).

Copy this into SE24 / ADT and activate:

```abap
CLASS zcl_vx_08_sample_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

PUBLIC SECTION.
  CONSTANTS:
    gc_default_plant TYPE werks_d VALUE '1710',
    gc_fert_max      TYPE i VALUE 4,
    gc_hawa_max      TYPE i VALUE 14,
    gc_roh_max       TYPE i VALUE 18,
    gc_other_max     TYPE i VALUE 2,
    gc_monthly_cap   TYPE i VALUE 3,
    gc_status_requested TYPE char2 VALUE '01',
    gc_status_approved  TYPE char2 VALUE '02',
    gc_status_dispatched TYPE char2 VALUE '03',
    gc_status_rejected  TYPE char2 VALUE '04'.

  CLASS-METHODS:
    get_max_sample_qty IMPORTING iv_material TYPE matnr RETURNING VALUE(rv_max) TYPE i,
    get_status_text    IMPORTING iv_status TYPE char2 RETURNING VALUE(rv_text) TYPE string,
    is_monthly_cap_hit IMPORTING iv_customer TYPE kunnr iv_date TYPE dats RETURNING VALUE(rv_hit) TYPE abap_bool.
ENDCLASS.

CLASS zcl_vx_08_sample_rules IMPLEMENTATION.

  METHOD get_max_sample_qty.
    rv_max = gc_other_max.
    IF iv_material IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE mtart FROM mara INTO @DATA(lv_mtart) WHERE matnr = @iv_material.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE lv_mtart.
      WHEN 'FERT'. rv_max = gc_fert_max.
      WHEN 'HAWA'. rv_max = gc_hawa_max.
      WHEN 'ROH'.  rv_max = gc_roh_max.
      WHEN OTHERS. rv_max = gc_other_max.
    ENDCASE.
  ENDMETHOD.

  METHOD get_status_text.
    CASE iv_status.
      WHEN gc_status_requested. rv_text = 'Requested'.
      WHEN gc_status_approved.  rv_text = 'Approved'.
      WHEN gc_status_dispatched. rv_text = 'Dispatched'.
      WHEN gc_status_rejected.  rv_text = 'Rejected'.
      WHEN OTHERS. rv_text = 'Unknown'.
    ENDCASE.
  ENDMETHOD.

  METHOD is_monthly_cap_hit.
    rv_hit = abap_false.
    IF iv_customer IS INITIAL OR iv_date IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_first) = iv_date(6) && '01'.
    DATA lv_next_first TYPE dats.
    DATA lv_yr TYPE i = iv_date+0(4).
    DATA lv_mo TYPE i = iv_date+4(2).
    IF lv_mo = 12.
      lv_next_first = |{ lv_yr + 1 }01| && '01'.
    ELSE.
      lv_next_first = |{ lv_yr }| && |{ ( lv_mo + 1 ) PAD = 2 }| && '01'.
    ENDIF.

    CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL' EXPORTING date = lv_next_first days = -1 IMPORTING new_date = DATA(lv_last) EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      lv_last = iv_date.
    ENDIF.

    SELECT COUNT( * ) INTO @DATA(lv_count) FROM zvx_08_smpl_req WHERE customer = @iv_customer AND req_date BETWEEN @lv_first AND @lv_last AND req_status <> gc_status_rejected.
    rv_hit = COND #( WHEN lv_count >= gc_monthly_cap THEN abap_true ELSE abap_false ).
  ENDMETHOD.

ENDCLASS.
```

Keep all business numbers here; don't duplicate limits elsewhere.

---

## Step 4 — CDS Root View `ZVX_08_R_SampleRequest` (ADT)

Create a new DDL Source (Data Definition) named `ZVX_08_R_SampleRequest` and paste the following. Activate.

```abap
@AbapCatalog.sqlViewName: 'ZVXR08SR'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VX08 Root SampleRequest'
define root view entity ZVX_08_R_SampleRequest as select from zvx_08_smpl_req
{
  key mandt                   as Client,
  key request_uuid            as RequestUUID,
      request_no              as RequestNo            @ObjectModel.representativeKey,
      customer                as Customer,
      material                as Material,
      plant                   as Plant,
      quantity                as Quantity,
      uom                     as UoM,
      req_date                as ReqDate,
      req_status              as ReqStatus,
      reject_reason           as RejectReason,
      approved_by             as ApprovedBy,
      approved_on             as ApprovedOn,
      created_by              as CreatedBy            @Semantics.user.createdBy,
      created_at              as CreatedAt            @Semantics.systemDateTime.createdAt,
      last_changed_by         as LastChangedBy,
      last_changed_at         as LastChangedAt        @ObjectModel.etag,
      local_last_changed_at   as LocalLastChangedAt   @ObjectModel.localInstance,

  association [0..1] to I_Customer as _Customer on $projection.Customer = _Customer.BusinessPartner,
  association [0..1] to I_Product  as _Material  on $projection.Material = _Material.Product,
  association [0..1] to I_Plant    as _Plant     on $projection.Plant = _Plant.Plant,

  case when req_status = gc_status_rejected then 1
       when req_status = gc_status_requested then 2
       when req_status in ( gc_status_approved, gc_status_dispatched ) then 3
       else 3 end as StatusCriticality
}
```

Activation notes:
- Ensure the `@AbapCatalog.sqlViewName` value is ≤ 16 characters and unique.
- If standard interface views (`I_Customer`, `I_Product`, `I_Plant`) are not available in your system, replace associations with local value-help CDS or remove temporarily.

---

## Step 5 — Projection `ZVX_08_C_SampleRequest` + Metadata Extension

Projection (create as Data Definition):

```abap
@AbapCatalog.sqlViewName: 'ZVXC08SR'
@Metadata.allowExtensions: true
@EndUserText.label: 'VX08 Projection SampleRequest'
define view ZVX_08_C_SampleRequest as projection on ZVX_08_R_SampleRequest
{
  RequestUUID, RequestNo, Customer, Material, Plant, Quantity, UoM, ReqDate, ReqStatus, StatusCriticality
}
```

Metadata extension (separate DDL source) example:

```abap
@EndUserText.label: 'Metadata extension for VX08 SampleRequest'
annotate view ZVX_08_C_SampleRequest with
{
  @UI.lineItem: [
    { position: 10, value: RequestNo },
    { position: 20, value: Customer },
    { position: 30, value: Material },
    { position: 40, value: Quantity },
    { position: 50, value: UoM },
    { position: 60, value: ReqDate },
    { position: 70, value: ReqStatus, criticality: StatusCriticality }
  ],
  @UI.selectionFields: [ Customer, Material, ReqStatus ]
}
```

Activation order: root → projection → metadata extension.

---

## Step 6 — Behaviour Definition + Implementation (ADT)

Create a Behaviour Definition for `ZVX_08_R_SampleRequest` and paste the BDEF below. Then use ADT to generate the Behaviour Implementation class `ZBP_VX_08_SAMPLE_IMPL` and implement determinations, validations and the approve action.

Behaviour definition (example):

```abap
behaviour for ZVX_08_R_SampleRequest alias SampleRequest persistent table zvx_08_smpl_req
{
  versioning strict;
  lock master;
  authorization master ( instance );

  key RequestUUID : Field( type guid ) { numbering managed; }

  field RequestNo : readonly;
  field ReqStatus : readonly;
  field UoM       : readonly;
  field ApprovedBy: readonly;
  field ApprovedOn: readonly;

  field Customer : mandatory;
  field Material : mandatory;
  field Quantity : mandatory;

  etag LastChangedAt : Lock;
  etag LocalLastChangedAt : LocalLock;

  create; update; delete;

  action approve result [1] $self implementation in class zbp_vx_08_sample_impl;

  determinations
    set_initial_values on modify { create } implementation in class zbp_vx_08_sample_impl;
    derive_uom         on modify { field Material } implementation in class zbp_vx_08_sample_impl;

  validations
    validate_material on save implementation in class zbp_vx_08_sample_impl;
    validate_customer on save implementation in class zbp_vx_08_sample_impl;
    validate_quantity on save implementation in class zbp_vx_08_sample_impl;
}
```

Implementation notes (what to implement in generated class):
- set_initial_values: set Plant = gc_default_plant, ReqDate = sy-datum, ReqStatus = gc_status_requested, generate RequestNo via SNRO.
- derive_uom: read MARA~MEINS and set UoM (user cannot edit UoM).
- validate_material: ensure MARA exists and MARC entry exists for material+plant — raise ZVX_08_MSG-001/002.
- validate_customer: ensure KNA1 exists and not blocked — raise ZVX_08_MSG-003/004.
- validate_quantity: ensure quantity > 0 and ≤ get_max_sample_qty — raise ZVX_08_MSG-005/006. Optionally check monthly cap and raise 007.
- approve action: only allowed when ReqStatus = '01'; set ReqStatus='02', ApprovedBy = current user, ApprovedOn = sy-datum; use response object to report errors.

Use `io_response->add_message(...)` in validations so messages appear in Fiori.

---

## Step 7 — Service Definition `ZVX_08_UI_SAMPLEREQ` and Service Binding

Create a CDS service exposing the projection and value-help entities and create an OData V4 – UI service binding.

Service definition example:

```abap
@EndUserText.label: 'VX08 SampleRequest service'
define service ZVX_08_UI_SAMPLEREQ {
  expose ZVX_08_C_SampleRequest as SampleRequest;
  expose I_Customer as Customers;
  expose I_Product  as Products;
  expose I_Plant    as Plants;
}
```

Create a Service Binding (OData V4 – UI), activate it, then open the Fiori Preview (right-click binding → Preview) to test create/save/approve flows.

---

## Step 8 — Classic ALV Report `ZVX_08_SAMPLE_REPORT` (SE38 / ADT)

I added the full ALV report source as a file in the repository: `ZVX_08_SAMPLE_REPORT.abap`. You can copy/paste it into SE38 or create an ABAP program in ADT and paste the contents.

Report highlights:
- SELECT-OPTIONS for customer/material/req_date
- Status dropdown populated by VRM_SET_VALUES
- Checkbox to filter requests >= 50% of allowed quantity (calls zcl_vx_08_sample_rules=>get_max_sample_qty)
- Single SELECT joining zvx_08_smpl_req with KNA1 and MAKT (use SPRAS = sy-langu)
- Display using CL_SALV_TABLE with readable headings and top-of-page info

See file: `ZVX_08_SAMPLE_REPORT.abap` in repository.

---

## Step 9 — Testing checklist & screenshots

Capture these from Fiori Preview and save locally (evidence/):
1. `01_create.png` — New request saved OK (UoM auto-filled; status Requested)
2. `02_val_qty.png` — Quantity validation firing (message visible)
3. `03_val_cust.png` — Blocked-customer validation
4. `04_approve.png` — Request after approval (status 02, ApprovedBy stamped)
5. `05_feature.png` — Approve button greyed out on non-allowed instance
6. `06_table.png` — Table preview with at least 4 rows across statuses

---

## Step 10 — Number range (safe RequestNo) — recommended

Create SNRO object `ZVXR08_REQNO` and use `NUMBER_GET_NEXT` or `CL_NUMBER_RANGE` in set_initial_values to get the next request number. Avoid SELECT MAX+1 in production.

Example snippet (use in determination):

```abap
DATA lv_num TYPE i.
CALL FUNCTION 'NUMBER_GET_NEXT'
  EXPORTING
    nrpn      = 'ZVXR08_REQNO'
    no_object = 'ZVXR08_REQNO'
    quantity  = 1
  IMPORTING
    number    = lv_num.
IF sy-subrc <> 0.
  io_response->add_message( iv_msgid = 'ZVX_08_MSG' iv_msgno = '008' ).
ELSE.
  lv_numc = |{ lv_num PAD = 10 }|.
  " assign to RequestNo field in update table
ENDIF.
```

---

## Step 11 — Design defence & notes

- Validations run on SAVE (not on every keystroke) because they enforce business invariants that must hold at commit time.
- `RequestNo` is readonly and set in a determination to allow safe human-friendly numbering and concurrent creation.
- `etag` on `LastChangedAt` provides optimistic locking for concurrency control.
- `get_features` controls the Approve button enablement so the UI does not show invalid affordances.

---

Files included in this repository (root):
- README.md (this file)
- ZVX_08_SAMPLE_REPORT.abap (ALV report source — copy into SE38/ADT)

If you want the full Behaviour Implementation class file (`ZBP_VX_08_SAMPLE_IMPL.abap`) added to the repo as a ready-to-paste ADT class, confirm your ABAP/RAP stack (example: ABAP 7.54 / 7.56) and I will add it in the next commit.

