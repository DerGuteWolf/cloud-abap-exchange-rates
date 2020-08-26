CLASS zcl_exchange_rates_logs DEFINITION PUBLIC CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_http_service_extension .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_exchange_rates_logs IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.
    " Dummy, thus nothing todo
  ENDMETHOD.
ENDCLASS.
