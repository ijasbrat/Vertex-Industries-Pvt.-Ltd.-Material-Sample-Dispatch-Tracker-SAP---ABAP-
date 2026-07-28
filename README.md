# ZVX_08 — Sample Request RAP Application (Eclipse/ADT instructions)

This README is tailored for developers who will implement steps 4+ using Eclipse (ABAP Development Tools / ADT). It complements the existing step‑by‑step material already in the `vx08-sample-app/` folder and explains exactly which ADT menu options to use and what to paste where. I pushed a polished README and code templates to the repository; this update focuses on the ADT/Eclipse workflow for CDS, behaviour, service binding and preview.

Quick links (templates already in the repo)
- Step files in `vx08-sample-app/`:
  - Table notes: vx08-sample-app/01_table_SE11.txt
  - Messages: vx08-sample-app/02_messages_ZVX_08_MSG.txt
  - Utility class: vx08-sample-app/03_class_ZCL_VX_08_SAMPLE_RULES.abap
  - Root CDS: vx08-sample-app/04_cds_ZVX_08_R_SampleRequest.cds
  - Projection CDS: vx08-sample-app/05_cds_ZVX_08_C_SampleRequest.cds
  - Metadata ext: vx08-sample-app/06_metadata_ZVX_08_C_SampleRequest.ext.cds
  - Behaviour def: vx08-sample-app/07_behavior_ZVX_08_R_SampleRequest.behaviour.abap
  - Behaviour impl guidance: vx08-sample-app/08_impl_ZBP_VX_08_SAMPLE_IMPL.txt
  - Service def: vx08-sample-app/09_service_ZVX_08_UI_SAMPLEREQ.cds
  - ALV report: vx08-sample-app/10_report_ZVX_08_SAMPLE_REPORT.abap
  - Prompt log template: vx08-sample-app/11_prompt_log_08.txt

---

Important preface for ADT work
- Use Eclipse with ABAP Development Tools connected to the ABAP backend where you'll create the objects.
- Use a transportable package (not $TMP) for production/deployed objects. For practice, a local package is acceptable but recommended to choose a transportable package so objects can be moved.
- Follow the sequence: Table (SE11) → Messages (SE91) → Utility class (SE24) → CDS root (ADT) → CDS projection + metadata ext (ADT) → Behaviour def (ADT) → Behaviour implementation (ADT generated skeleton) → Service definition + Service Binding (ADT) → Fiori Preview.

---

Step 4 (ADT/Eclipse) — Create CDS root view entity `ZVX_08_R_SampleRequest`
1. Open Eclipse with ADT and log into your ABAP system.
2. In the Project Explorer, right‑click your package → New → Other ABAP Repository Object.
3. In the dialog choose 'Data Definition' (DDL Source) and click Next.
4. Enter:
   - Name: `ZVX_08_R_SampleRequest`
   - Description: "VX08 Root SampleRequest"
   - Package: choose your package
   - Click Finish.
5. Eclipse opens the DDL editor. Replace the skeleton with the contents of `vx08-sample-app/04_cds_ZVX_08_R_SampleRequest.cds` (open the file in the GitHub repo and copy/paste). Key items to preserve:
   - `@AbapCatalog.sqlViewName` (short unique name ≤16 chars)
   - `@ObjectModel.representativeKey` on `RequestNo`
   - `@Semantics.user.createdBy` / `@Semantics.systemDateTime.createdAt`
   - `@ObjectModel.etag` on `LastChangedAt` and `@ObjectModel.localInstance` on `LocalLastChangedAt`
   - Associations to `I_Customer`, `I_Product`, `I_Plant` (these are standard value‑help CDS entities; if your system uses different names adapt them)
6. Save and Activate (Ctrl+S, then right‑click editor → Activate). Fix any activation errors (common reasons below).

Common CDS activation issues and fixes
- "Field not found" — check the exact column names in your SE11 table (`ZVX_08_SMPL_REQ`) match the CDS fields (case‑insensitive but spelling must match).
- `sqlViewName` too long — shorten to 16 chars (e.g., `ZVXR08SR`).
- Missing associations types — if `I_Customer` or `I_Product` do not exist in your system, replace with local value‑help CDS or remove association temporarily and add later.

---

Step 5 (ADT/Eclipse) — Create CDS projection `ZVX_08_C_SampleRequest` and metadata extension
1. Projection (DDL Source):
   - Right‑click package → New → Other ABAP Repository Object → Data Definition.
   - Name: `ZVX_08_C_SampleRequest` → Finish.
   - Paste content from `vx08-sample-app/05_cds_ZVX_08_C_SampleRequest.cds`.
   - Save & Activate.
2. Metadata extension (separate DDL Source file):
   - Right‑click package → New → Other ABAP Repository Object → Data Definition.
   - Name: `ZVX_08_C_SampleRequest.ext` (the .ext suffix is conventional for metadata extensions) or choose the same name with `.ext.cds` and *Type* = 'Data Definition'.
   - Paste content from `vx08-sample-app/06_metadata_ZVX_08_C_SampleRequest.ext.cds`.
   - Save & Activate.
3. Verify in ADT: the Projection shows UI annotations when the metadata extension is active (ADT UI preview may show annotation markers).

Notes
- Keep UI annotations only in the metadata extension file — this keeps the root model clean and reusable.
- Use `@UI.lineItem` for list columns and `@UI.selectionField` or `selectionFields` specifying Customer, Material, ReqStatus.

---

Step 6 (ADT/Eclipse) — Create Behaviour Definition (BDEF)
1. Right‑click package → New → Other ABAP Repository Object → Business Object → Behaviour Definition (or search 'Behaviour Definition' in New wizard).
2. Name the BDEF: `ZVX_08_R_SampleRequest` (same as CDS root by convention) and select the root view entity `ZVX_08_R_SampleRequest` when prompted.
3. Eclipse will create a `.behaviour.abap` file. Replace content with `vx08-sample-app/07_behavior_ZVX_08_R_SampleRequest.behaviour.abap` (copy/paste).
4. Important BDEF details to confirm in the file:
   - `versioning strict` (strict behaviour)
   - `lock master` and `authorization master ( instance )`
   - `key RequestUUID : Field( type guid ) { numbering managed; }` to let the framework manage the technical UUID numbering
   - `etag` mapping for LastChangedAt and LocalLastChangedAt
   - readonly properties (RequestNo, ReqStatus, UoM, ApprovedBy, ApprovedOn) and mandatory flags for Customer, Material, Quantity
   - declarations for determinations and validations
5. Save and Activate the behaviour definition.

Common BDEF activation issues
- If the CDS root changed, the BDEF may reference fields not present — fix the CDS first and reactivate.
- ADT will list syntax problems and missing annotations; follow the error markers.

---

Step 7 (ADT/Eclipse) — Create Behaviour Implementation class `ZBP_VX_08_SAMPLE_IMPL`
1. In the BDEF editor, right‑click inside the file → 'Create Behaviour Implementation' (or use the New wizard: Other ABAP Repository Object → Business Object → Behaviour Implementation).
2. Choose a name: `ZBP_VX_08_SAMPLE_IMPL` and confirm. ADT will generate a class skeleton with correctly typed method signatures for determinations, validations and action handlers.
3. Open the generated class in ADT (it appears in the Project Explorer under Classes) and implement the methods.
   - Use the guidance file `vx08-sample-app/08_impl_ZBP_VX_08_SAMPLE_IMPL.txt` as the logic reference and paste logic into the generated methods.
   - Typical method parameters provided by ADT: `it_new`, `it_modified`, `it_keys`, `io_response`, `io_request_context` — use `io_response->add_message()` to add messages from `ZVX_08_MSG` (this ensures they show up in Fiori).
4. Save and Activate the implementation class.

Important implementation tips
- For RequestNo generation use a number range (SNRO) rather than MAX+1 to avoid concurrency issues. Create SNRO object `ZVXR08_REQNO` in transaction SNRO and call `NUMBER_GET_NEXT` or `cl_number_range` class.
- Determinations run in MODIFY phase (create/modify triggers); validations run in SAVE phase. Put lookups in determinations where you can auto‑fill fields (deriveUom), but enforce existence checks in save validations.

---

Step 8 (ADT/Eclipse) — Create Service Definition & Binding
1. Right‑click package → New → Other ABAP Repository Object → Data Definition.
   - Name: `ZVX_08_UI_SAMPLEREQ` and paste content from `vx08-sample-app/09_service_ZVX_08_UI_SAMPLEREQ.cds`.
2. Save and Activate the service definition.
3. Create Service Binding: right‑click the service definition in the Project Explorer → New → Service Binding.
   - Choose: OData V4 – UI (OData v4 – UI is the recommended binding for RAP Fiori Elements apps).
   - Accept defaults or adjust as needed; activate the binding.
4. Open Fiori Preview: Right‑click the Service Binding → Open in Web Browser → Fiori Elements Preview (or 'Run' if available). This opens the generated Fiori List Report where you can create items and test validations.

Notes on Service Binding
- If the Fiori Preview doesn't show your custom action (Approve), ensure the behaviour implementation is active and the action is declared in the BDEF. Also check authorization settings.

---

Step 9 — Test in Fiori Preview & capture evidence
1. Create a new request: check UoM auto‑fill (deriveUom), default Plant, default Status '01' and friendly RequestNo.
2. Try invalid material → see message from ZVX_08_MSG-001/002.
3. Try blocked customer → see message ZVX_08_MSG-004.
4. Enter quantity > allowed → see message ZVX_08_MSG-006.
5. Approve a request: the Approve action should set status '02' and stamp ApprovedBy / ApprovedOn.
6. Capture the required screenshots and save them in an `evidence/` folder locally (not committed here for privacy):
   - 01_create.png, 02_val_qty.png, 03_val_cust.png, 04_approve.png, 05_feature.png, 06_table.png

---

Step 10 — Classic ALV report (SE38/ADT)
- If you prefer ADT for the report, create a new ABAP program in ADT (New → ABAP Program) and paste the content of `vx08-sample-app/10_report_ZVX_08_SAMPLE_REPORT.abap`.
- Ensure `VRM_SET_VALUES` is used to populate status dropdown at INITIALIZATION and call utility class for the 50% computation.

---

Troubleshooting & common fixes
- "Action not visible in Fiori": ensure the behaviour implementation class is active and the BDEF declares the action; check feature control expressions and authorization.
- "ETag mismatch" errors when saving: ensure the CDS root has `@ObjectModel.etag` on the total change timestamp and `@ObjectModel.localInstance` on the local instance field. The BDEF must also declare `etag` mapping.
- Messages not showing: use `io_response->add_message( iv_msgid = 'ZVX_08_MSG' iv_msgno = '006' ... )` in validations; the message class id & number must exist in SE91.

---

If you want me to also:
- generate the full ADT‑compatible behaviour implementation class (complete with method bodies ready to paste) — tell me your ABAP stack version (e.g., 7.54, 7.56), and I will add the class source into `vx08-sample-app/` and commit it; or
- embed example Fiori screenshots into README (you must supply images) — I will add them under `docs/evidence/` and reference them in README.

I have updated README and added ADT/Eclipse‑specific instructions; the templates are already in `vx08-sample-app/`. Follow the ADT steps above from Step 4 onwards and paste the template contents into the corresponding ADT editors. If you hit activation errors, paste the ADT error text here and I'll guide the fixes line‑by‑line.
