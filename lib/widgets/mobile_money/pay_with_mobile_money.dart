import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutterwave/core/core_utils/flutterwave_api_utils.dart';
import 'package:flutterwave/core/mobile_money/mobile_money_payment_manager.dart';
import 'package:flutterwave/models/francophone_country.dart';
import 'package:flutterwave/models/requests/authorization.dart';
import 'package:flutterwave/models/requests/mobile_money/mobile_money_request.dart';
import 'package:flutterwave/models/responses/charge_response.dart';
import 'package:flutterwave/utils/CountryCode/CountryCode.dart';
import 'package:flutterwave/utils/flutterwave_constants.dart';
import 'package:flutterwave/utils/flutterwave_currency.dart';
import 'package:flutterwave/utils/flutterwave_utils.dart';
import 'package:flutterwave/widgets/card_payment/authorization_webview.dart';
import 'package:flutterwave/widgets/flutterwave_view_utils.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class PayWithMobileMoney extends StatefulWidget {
  final MobileMoneyPaymentManager _paymentManager;

  PayWithMobileMoney(this._paymentManager);

  @override
  _PayWithMobileMoneyState createState() => _PayWithMobileMoneyState();
}

class _PayWithMobileMoneyState extends State<PayWithMobileMoney> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _networkController = TextEditingController();
  final TextEditingController _francophoneCountryCotroller =
      TextEditingController();
  final TextEditingController _voucherController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  bool isPayButtonEnables = false;
  bool isProcessing = false;

  bool isNumberValid = false;
  String? countryCode = 'GH';
  PhoneNumber number = PhoneNumber(isoCode: 'GH');
  BuildContext? loadingDialogContext;
  String? selectedNetwork;
  TextEditingController controller = TextEditingController();
  CountryCode? selectedCode;
  FrancoPhoneCountry? selectedFrancophoneCountry;
  String updatedNumber = "";

  @override
  Widget build(BuildContext context) {
    final String initialPhoneNumber = updatedNumber.isEmpty
        ? this.widget._paymentManager.phoneNumber
        : updatedNumber;
    // this._phoneNumberController.text = initialPhoneNumber;

    final String currency = this.widget._paymentManager.currency;

    isPayButtonEnables = selectedNetwork != "" && isNumberValid;
    return MaterialApp(
      debugShowCheckedModeBanner: widget._paymentManager.isDebugMode,
      home: GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: Scaffold(
          body: Scaffold(
            key: this._scaffoldKey,
            resizeToAvoidBottomInset: false,
            appBar:
                FlutterwaveViewUtils.appBar(context, _getPageTitle(currency)),
            body: Padding(
              padding: EdgeInsets.only(left: 18, right: 18),
              child: Container(
                // margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                width: double.infinity,
                child: Form(
                  key: this._formKey,
                  child: ListView(
                    children: [
                      Container(
                        child: InternationalPhoneNumberInput(
                          onInputChanged: (PhoneNumber number) {
                            setState(() {
                              countryCode = number.isoCode;
                              updatedNumber = number.phoneNumber.toString();
                            });
                          },
                          onInputValidated: (bool value) {
                            setState(() {
                              isNumberValid = value;
                            });
                          },
                          ignoreBlank: true,
                          autoValidateMode: AutovalidateMode.always,
                          initialValue: PhoneNumber(isoCode: countryCode),
                          textFieldController: this._phoneNumberController,
                          inputDecoration: InputDecoration(
                            isDense: true,
                            fillColor: Colors.white,
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                width: 0,
                                style: BorderStyle.none,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          selectorConfig: SelectorConfig(
                            leadingPadding: 10,
                            trailingSpace: false,
                            selectorType: PhoneInputSelectorType.DIALOG,
                          ),
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: .5),
                          // color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
                        width: double.infinity,
                        child: TextFormField(
                          decoration: InputDecoration(
                            isDense: true,
                            fillColor: Colors.white,
                            hintText: 'Voucher (optional)',
                            hintStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                width: 1,
                                style: BorderStyle.none,
                                color: Colors.black,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                width: 1.1,
                                style: BorderStyle.solid,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          controller: this._voucherController,
                          onChanged: (v) {
                            setState(() {});
                          },
                        ),
                      ),
                      Visibility(
                        visible: currency.toUpperCase() ==
                                FlutterwaveCurrency.XAF ||
                            currency.toUpperCase() == FlutterwaveCurrency.XOF,
                        child: Container(
                          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
                          width: double.infinity,
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: "Country",
                              hintText: "Country",
                            ),
                            controller: this._francophoneCountryCotroller,
                            readOnly: true,
                            onTap: this._showFrancophoneBottomSheet,
                            validator: (value) => value != null && value.isEmpty
                                ? "country is required"
                                : null,
                          ),
                        ),
                      ),
                      Visibility(
                        visible:
                            currency.toUpperCase() == FlutterwaveCurrency.GHS,
                        child: Container(
                          margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
                          width: double.infinity,
                          child: TextFormField(
                            decoration: InputDecoration(
                              fillColor: Colors.white,
                              isDense: true,
                              hintText: 'Network',
                              hintStyle: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  width: 1,
                                  style: BorderStyle.none,
                                  color: Colors.black,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  width: 1.1,
                                  style: BorderStyle.solid,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            controller: this._networkController,
                            readOnly: true,
                            onTap: this._showNetworksBottomSheet,
                            validator: (value) => value != null && value.isEmpty
                                ? "Network is required"
                                : null,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 18.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 10.0,
                                  color: Colors.black,
                                ),
                                SizedBox(
                                  width: 5.0,
                                ),
                                Text(
                                  "SECURED BY FLUTTERWAVE",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10.0,
                                      fontFamily: "FLW",
                                      letterSpacing: 1.0),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.only(top: 0, bottom: 20, left: 20, right: 20),
                child: Container(
                    height: 50,
                    child: MaterialButton(
                        onPressed: !isProcessing
                            ? isPayButtonEnables
                                ? () {
                                    this._onPayPressed();
                                  }
                                : null
                            : null,
                        color: Theme.of(context).primaryColor,
                        disabledColor: Theme.of(context).primaryColorLight,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: new BorderRadius.circular(9.0)),
                        child: new Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Center(
                                child: !isProcessing
                                    ? new Text(
                                        "Pay",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    : SpinKitThreeBounce(
                                        size: 20, color: Colors.white),
                              ),
                            )
                          ],
                        ))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    this._phoneNumberController.dispose();
  }

  void _onPayPressed() {
    if (this._formKey.currentState!.validate()) {
      final MobileMoneyPaymentManager pm = this.widget._paymentManager;
      FlutterwaveViewUtils.showConfirmPaymentModal(
          this.context, pm.currency, pm.amount, this._handlePayment);
    }
  }

  void _showLoading(String message) {
    setState(() {
      isProcessing = true;
    });
  }

  void _closeDialog() {
    if (this.loadingDialogContext != null) {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _showBottomSheet(final Widget widget) {
    showModalBottomSheet(context: this.context, builder: (context) => widget);
  }

  void _showFrancophoneBottomSheet() {
    this._showBottomSheet(this._getFrancoPhoneCountries());
  }

  void _showNetworksBottomSheet() {
    this._showBottomSheet(this._getNetworksThatAllowMobileMoney());
  }

  Widget _getNetworksThatAllowMobileMoney() {
    final networks =
        FlutterwaveCurrency.getAllowedMobileMoneyNetworksByCurrency(
            this.widget._paymentManager.currency);
    return Container(
      height: 220,
      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
      color: Colors.white,
      child: ListView(
        children: networks
            .map((network) => ListTile(
                  onTap: () => {this._handleNetworkTap(network)},
                  title: Column(
                    children: [
                      Text(
                        network,
                        textAlign: TextAlign.start,
                        style: TextStyle(color: Colors.black),
                      ),
                      SizedBox(height: 4),
                      Divider(height: 1)
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _getFrancoPhoneCountries() {
    final francoPhoneCountries = FlutterwaveUtils.getFrancoPhoneCountries(
        this.widget._paymentManager.currency);
    return Container(
      height: 220,
      margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
      color: Colors.white,
      child: ListView(
        children: francoPhoneCountries
            .map((country) => ListTile(
                  onTap: () =>
                      {this._handleFrancophoneCountrySelected(country)},
                  title: Column(
                    children: [
                      Text(
                        country.name,
                        textAlign: TextAlign.start,
                        style: TextStyle(color: Colors.black),
                      ),
                      SizedBox(height: 4),
                      Divider(height: 1)
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _handleNetworkTap(final String selectedNetwork) {
    this._removeFocusFromView();
    this.setState(() {
      this.selectedNetwork = selectedNetwork;
      this._networkController.text = selectedNetwork;
    });
    Navigator.pop(this.context);
  }

  _handleFrancophoneCountrySelected(final FrancoPhoneCountry country) {
    this._removeFocusFromView();
    this.setState(() {
      this.selectedFrancophoneCountry = country;
      this._francophoneCountryCotroller.text = country.name;
    });
    Navigator.pop(this.context);
  }

  void _removeFocusFromView() {
    FocusScope.of(this.context).requestFocus(FocusNode());
  }

  String _getPageTitle(final String currency) {
    switch (currency.toUpperCase()) {
      case FlutterwaveCurrency.GHS:
        return "Ghana Mobile Money";
      case FlutterwaveCurrency.RWF:
        return "Rwanda Mobile Money";
      case FlutterwaveCurrency.ZMW:
        return "Zambia Mobile Money";
      case FlutterwaveCurrency.UGX:
        return "Uganda Mobile Money";
      case FlutterwaveCurrency.XAF:
        return "Francophone Mobile Money";
      case FlutterwaveCurrency.XOF:
        return "Francophone Mobile Money";
    }
    return "";
  }

  void _showSnackBar(String message) {
    SnackBar snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
      ),
    );
    this._scaffoldKey.currentState!.showSnackBar(snackBar);
  }

  void _handlePayment() async {
    Navigator.pop(this.context);

    this._showLoading(FlutterwaveConstants.INITIATING_PAYMENT);

    final MobileMoneyPaymentManager mobileMoneyPaymentManager =
        this.widget._paymentManager;

    if (this.updatedNumber.isNotEmpty) {
      this.widget._paymentManager.phoneNumber = this.updatedNumber.trim();
    }
    final MobileMoneyRequest request = MobileMoneyRequest(
      amount: mobileMoneyPaymentManager.amount,
      currency: mobileMoneyPaymentManager.currency,
      network: this.selectedNetwork == null ? "" : this.selectedNetwork!,
      txRef: mobileMoneyPaymentManager.txRef,
      fullName: mobileMoneyPaymentManager.fullName,
      email: mobileMoneyPaymentManager.email,
      phoneNumber: this.widget._paymentManager.phoneNumber.trim(),
      voucher: this._voucherController.text,
      redirectUrl: mobileMoneyPaymentManager.redirectUrl,
      country: this.selectedFrancophoneCountry == null
          ? ""
          : this.selectedFrancophoneCountry!.countryCode,
    );

    final http.Client client = http.Client();
    try {
      final response =
          await mobileMoneyPaymentManager.payWithMobileMoney(request, client);
      this._closeDialog();

      if (FlutterwaveConstants.SUCCESS == response.status &&
          FlutterwaveConstants.CHARGE_INITIATED == response.message) {
        if (response.meta!.authorization!.mode == Authorization.REDIRECT &&
            response.meta!.authorization!.redirect != null) {
          this._openOtpScreen(response.meta!.authorization!.redirect!);
          return;
        }
        if (response.meta!.authorization!.mode == Authorization.CALLBACK) {
          this._verifyPayment(response.data!.flwRef!);
          return;
        }
        this._showSnackBar(response.message!);
      } else {
        this._showSnackBar(response.message!);
      }
    } catch (error) {
      this._closeDialog();
      this._showSnackBar(error.toString());
    }
  }

  Future<dynamic> _openOtpScreen(String url) async {
    final result = await Navigator.push(
      this.context,
      MaterialPageRoute(
          builder: (context) => AuthorizationWebview(
              Uri.encodeFull(url), this.widget._paymentManager.redirectUrl!)),
    );
    if (result != null) {
      if (result.runtimeType == " ".runtimeType) {
        this._verifyPayment(result);
      } else {
        this._showSnackBar(result["message"]);
      }
    } else {
      this._showSnackBar("Transaction not completed.");
    }
  }

  void _verifyPayment(final String flwRef) async {
    final timeoutInMinutes = 4;
    final timeOutInSeconds = timeoutInMinutes * 60;
    final requestIntervalInSeconds = 7;
    final numberOfTries = timeOutInSeconds / requestIntervalInSeconds;
    int intialCount = 0;

    ChargeResponse? response;

    this._showLoading(FlutterwaveConstants.VERIFYING);

    Timer.periodic(Duration(seconds: requestIntervalInSeconds), (timer) async {
      if (intialCount >= numberOfTries && response != null) {
        timer.cancel();
        return this._onComplete(response!);
      }
      final client = http.Client();
      try {
        response = await FlutterwaveAPIUtils.verifyPayment(
            flwRef,
            client,
            this.widget._paymentManager.publicKey,
            this.widget._paymentManager.isDebugMode);
        if ((response!.data!.status == FlutterwaveConstants.SUCCESSFUL ||
                response!.data!.status == FlutterwaveConstants.SUCCESS) &&
            response!.data!.amount == this.widget._paymentManager.amount &&
            response!.data!.flwRef == flwRef) {
          timer.cancel();
          this._onComplete(response!);
        } else {
          if (!timer.isActive) {
            this._closeDialog();
            this._showSnackBar(response!.message!);
          }
        }
      } catch (error) {
        timer.cancel();
        this._closeDialog();
        this._showSnackBar(error.toString());
      } finally {
        intialCount = intialCount + 1;
      }
    });
  }

  void _onComplete(final ChargeResponse chargeResponse) {
    this._closeDialog();
    Navigator.pop(this.context, chargeResponse);
  }
}
