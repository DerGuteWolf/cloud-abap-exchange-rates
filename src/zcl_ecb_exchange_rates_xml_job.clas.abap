CLASS zcl_ecb_exchange_rates_xml_job DEFINITION
  PUBLIC INHERITING FROM zcl_ecb_exchange_rates_xml
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    METHODS if_oo_adt_classrun~main REDEFINITION.

  PROTECTED SECTION.
    CONSTANTS lc_log_object_name    TYPE if_bali_object_handler=>ty_object          VALUE 'ZECB_EXCHANGE_RATES'.
    CONSTANTS lc_log_subobject_name TYPE if_bali_object_handler=>ty_subobject       VALUE 'ZECB_EXCHANGE_RATES'.
    CONSTANTS lc_log_external_id    TYPE if_xco_cp_bal_log_header=>tv_external_id   VALUE 'ZECB_EXCHANGE_RATES'.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ecb_exchange_rates_xml_job IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    CONSTANTS lc_catalog_name      TYPE cl_apj_dt_create_content=>ty_catalog_name  VALUE 'ZECB_EXCHANGE_RATES'.
    CONSTANTS lc_catalog_text      TYPE cl_apj_dt_create_content=>ty_text          VALUE 'Catalog for ZECB_EXCHANGE_RATES'.
    CONSTANTS lc_class_name        TYPE cl_apj_dt_create_content=>ty_class_name    VALUE 'ZCL_ECB_EXCHANGE_RATES_XML_JOB'.

    CONSTANTS lc_template_name     TYPE cl_apj_dt_create_content=>ty_template_name VALUE 'ZECB_EXCHANGE_RATES_XML_JOB'.
    CONSTANTS lc_template_text     TYPE cl_apj_dt_create_content=>ty_text          VALUE 'Job Templ ZECB_EXCHANGE_RATES_XML_JOB'.

    CONSTANTS lc_transport_request TYPE cl_apj_dt_create_content=>ty_transport_request VALUE 'NSCK900037'.
    CONSTANTS lc_package           TYPE cl_apj_dt_create_content=>ty_package           VALUE 'ZEXCHANGE_RATES'.

    CONSTANTS lc_log_object_text    TYPE if_bali_object_handler=>ty_object_text    VALUE 'Log Object for ZECB_EXCHANGE_RATES'.
    CONSTANTS lc_log_subobject_text TYPE if_bali_object_handler=>ty_subobject_text VALUE 'Log Sub-Object for ZECB_EXCHANGE_RATES'.

    DATA(lo_dt) = cl_apj_dt_create_content=>get_instance( ).

    " Create job catalog entry (corresponds to the former report incl. selection parameters)
    " Provided implementation class iv_class_name shall implement two interfaces:
    " - if_apj_dt_exec_object to provide the definition of all supported selection parameters of the job
    "   (corresponds to the former report selection parameters) and to provide the actual default values
    " - if_apj_rt_exec_object to implement the job execution
    TRY.
        lo_dt->create_job_cat_entry(
            iv_catalog_name       = lc_catalog_name
            iv_class_name         = lc_class_name
            iv_text               = lc_catalog_text
            iv_catalog_entry_type = cl_apj_dt_create_content=>class_based
            iv_transport_request  = lc_transport_request
            iv_package            = lc_package
        ).
        out->write( |Job catalog entry created successfully| ).

      CATCH cx_apj_dt_content INTO DATA(lx_apj_dt_content).
        out->write( |Creation of job catalog entry failed: { lx_apj_dt_content->get_text( ) }| ).
    ENDTRY.

    " Create job template (corresponds to the former system selection variant) which is mandatory
    " to select the job later on in the Fiori app to schedule the job
    DATA lt_parameters TYPE if_apj_dt_exec_object=>tt_templ_val.

    NEW zcl_ecb_exchange_rates_xml_job( )->if_apj_dt_exec_object~get_parameters(
      IMPORTING
        et_parameter_val = lt_parameters
    ).

    TRY.
        lo_dt->create_job_template_entry(
            iv_template_name     = lc_template_name
            iv_catalog_name      = lc_catalog_name
            iv_text              = lc_template_text
            it_parameters        = lt_parameters
            iv_transport_request = lc_transport_request
            iv_package           = lc_package
        ).
        out->write( |Job template created successfully| ).

      CATCH cx_apj_dt_content INTO lx_apj_dt_content.
        out->write( |Creation of job template failed: { lx_apj_dt_content->get_text( ) }| ).
        RETURN.
    ENDTRY.

    DATA(lo_log_object) = cl_bali_object_handler=>get_instance( ).
    TRY.
        lo_log_object->create_object( EXPORTING iv_object = lc_log_object_name
                                                iv_object_text = lc_log_object_text
                                                it_subobjects = VALUE #( ( subobject = lc_log_subobject_name subobject_text = lc_log_subobject_text ) )
                                                iv_package = lc_package
                                                iv_transport_request = lc_transport_request ).
      CATCH cx_bali_objects INTO DATA(lx_exception).
        out->write( |Creation of log object failed: { lx_exception->get_text( ) }| ).
    ENDTRY.

    out->write( |Log Object created successfully| ).
    DATA(lt_logs) = xco_cp_bal=>for->database( )->logs->where( VALUE #( ( xco_cp_bal=>log_filter->object( xco_cp_abap_sql=>constraint->equal( lc_log_object_name ) ) ) ) )->get( ).
    DATA(lt_messages) = lt_logs[ LINES( lt_logs ) ]->messages->all->get( ).
    out->write( |Currently { LINES( lt_logs ) } entries in log.| ).
    "DATA(value) = lt_messages1[ 1 ]->value-message->value.
    out->write( |Last entry consists of the following messages| ).
    LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<message>).
      out->write( |{ sy-index }: { <message>->value-message->get_text( ) } | ).
    ENDLOOP.
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    DATA messages TYPE cl_exchange_rates=>ty_messages.
    DATA(lo_log) = xco_cp_bal=>for->database( )->log->create(
      iv_object      = lc_log_object_name
      iv_subobject   = lc_log_subobject_name
      iv_external_id = lc_log_external_id
    ).
    TRY.
        parse_rates( EXPORTING exchangerates = get_rates( CHANGING messages = messages ) IMPORTING entries = DATA(entries) ).
        store_rates( EXPORTING entries = entries IMPORTING rates = DATA(rates) CHANGING messages = messages ).
      CATCH cx_root INTO DATA(lx_exception).
        lo_log->add_exception( lx_exception ).
    ENDTRY.
    IF messages IS INITIAL.
      lo_log->add_text( xco_cp=>string( |Succesful Run| ) ).
      RETURN.
    ENDIF.
    TRY.
        LOOP AT messages ASSIGNING FIELD-SYMBOL(<message>).
          lo_log->add_message( VALUE #( msgid = <message>-id msgno = <message>-number msgty = <message>-type msgv1 = <message>-message_v1 msgv2 = <message>-message_v2 msgv3 = <message>-message_v3 msgv4 = <message>-message_v4  ) ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_exception2).
        lo_log->add_exception( lx_exception2 ).
    ENDTRY.
  ENDMETHOD.

  METHOD if_apj_dt_exec_object~get_parameters.
    " No parameter -> Nothing todo
  ENDMETHOD.

ENDCLASS.
