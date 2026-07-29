REPORT zvx_08_sample_report.

TYPE-POOLS: vrm.

TABLES: zvx_08_smpl_req, kna1, makt.

*-----------------------------------------------------------------------
* Selection Screen
*-----------------------------------------------------------------------
SELECT-OPTIONS: so_cust FOR zvx_08_smpl_req-customer,
                so_mat  FOR zvx_08_smpl_req-material,
                so_date FOR zvx_08_smpl_req-req_date.
PARAMETERS: p_status TYPE zvx_08_smpl_req-req_status AS LISTBOX VISIBLE LENGTH 15.
PARAMETERS: p_above50 AS CHECKBOX.

INITIALIZATION.
  DATA: lt_status TYPE vrm_values.
  APPEND VALUE #( key = ''   text = 'All' ) TO lt_status.
  APPEND VALUE #( key = '01' text = 'Requested' ) TO lt_status.
  APPEND VALUE #( key = '02' text = 'Approved'  ) TO lt_status.
  APPEND VALUE #( key = '03' text = 'Dispatched') TO lt_status.
  APPEND VALUE #( key = '04' text = 'Rejected'  ) TO lt_status.
  CALL FUNCTION 'VRM_SET_VALUES' EXPORTING id = 'P_STATUS' values = lt_status.

AT SELECTION-SCREEN.
  IF so_date[] IS NOT INITIAL.
    LOOP AT so_date WHERE sign = 'I'.
      IF so_date-high > sy-datum.
        MESSAGE 'Request Date high cannot be in the future' TYPE 'E'.
      ENDIF.
    ENDLOOP.
  ENDIF.

START-OF-SELECTION.
  DATA: lt_result TYPE TABLE OF zvx_08_smpl_req,
        lt_join   TYPE TABLE OF zvx_08_smpl_req.

  SELECT a~request_no,
         a~customer,
         a~material,
         a~quantity,
         a~uom,
         a~req_date,
         a~req_status,
         b~name1,
         c~maktx
    FROM zvx_08_smpl_req AS a
    LEFT JOIN kna1 AS b ON b~kunnr = a~customer
    LEFT JOIN makt AS c ON c~matnr = a~material AND c~spras = sy-langu
    INTO TABLE @DATA(lt_join).

  IF p_above50 = abap_true.
    DATA lt_filtered TYPE TABLE OF zvx_08_smpl_req.
    LOOP AT lt_join INTO DATA(ls).
      DATA(lv_max) = zcl_vx_08_sample_rules=>get_max_sample_qty( ls-material ).
      IF ls-quantity * 100 >= lv_max * 50.
        APPEND ls TO lt_filtered.
      ENDIF.
    ENDLOOP.
    lt_result = lt_filtered.
  ELSE.
    lt_result = lt_join.
  ENDIF.

  " Optional: filter by status, customer, material and date selection
  IF p_status IS NOT INITIAL.
    DELETE lt_result WHERE req_status <> p_status.
  ENDIF.

  IF so_cust[] IS NOT INITIAL.
    DELETE lt_result WHERE customer NOT IN so_cust.
  ENDIF.

  IF so_mat[] IS NOT INITIAL.
    DELETE lt_result WHERE material NOT IN so_mat.
  ENDIF.

  IF so_date[] IS NOT INITIAL.
    DELETE lt_result WHERE req_date NOT IN so_date.
  ENDIF.

  " Build display table for ALV (simple cast, adapt columns if needed)
  DATA: lt_display TYPE STANDARD TABLE OF zvx_08_smpl_req.
  lt_display = lt_result.

  " Display using CL_SALV_TABLE
  TRY.
      DATA(lo_alv) = cl_salv_table=>factory( r_container = cl_gui_container=>default_screen r_table = lt_display ).
      lo_alv->get_columns( )->get_column( 'REQUEST_NO' )->set_long_text( 'Request No' ).
      lo_alv->get_columns( )->get_column( 'CUSTOMER' )->set_long_text( 'Customer' ).
      lo_alv->get_columns( )->get_column( 'MATERIAL' )->set_long_text( 'Material' ).
      lo_alv->get_columns( )->get_column( 'QUANTITY' )->set_long_text( 'Quantity' ).
      lo_alv->get_columns( )->get_column( 'UOM' )->set_long_text( 'UoM' ).
      lo_alv->get_columns( )->get_column( 'REQ_DATE' )->set_long_text( 'Request Date' ).
      lo_alv->get_columns( )->get_column( 'REQ_STATUS' )->set_long_text( 'Status' ).

      DATA(lv_title) = |VX08 Sample Requests — run by { sy-uname } on { sy-datum } — { lines( lt_display ) } records|.
      lo_alv->set_top_of_page( lv_title ).
      lo_alv->display( ).
    CATCH cx_salv_msg INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
