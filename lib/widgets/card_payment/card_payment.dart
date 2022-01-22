import 'package:credit_card_validator/validation_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutterwave/core/card_payment_manager/card_payment_manager.dart';
import 'package:flutterwave/core/core_utils/flutterwave_api_utils.dart';
import 'package:flutterwave/core/metrics/metric_manager.dart';
import 'package:flutterwave/interfaces/card_payment_listener.dart';
import 'package:flutterwave/models/requests/charge_card/charge_card_request.dart';
import 'package:flutterwave/models/requests/charge_card/charge_request_address.dart';
import 'package:flutterwave/models/responses/charge_response.dart';
import 'package:flutterwave/utils/flutterwave_constants.dart';
import 'package:flutterwave/widgets/card_payment/authorization_webview.dart';
import 'package:flutterwave/widgets/card_payment/request_address.dart';
import 'package:flutterwave/widgets/flutterwave_view_utils.dart';
import 'package:credit_card_validator/credit_card_validator.dart';
import 'package:credit_card_validator/card_number.dart';
import 'package:credit_card_type_detector/credit_card_type_detector.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

import 'request_otp.dart';
import 'request_pin.dart';

class CardPayment extends StatefulWidget {
  final CardPaymentManager _paymentManager;

  CardPayment(this._paymentManager);

  @override
  _CardPaymentState createState() => _CardPaymentState();
}

class _CardPaymentState extends State<CardPayment>
    implements CardPaymentListener {
  final _cardFormKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool cardIsValid = false;
  bool cardIsInValidRange = false;
  bool mMYYIsValid = false;
  bool ccvIsValid = false;
  bool ccvIsInRange = false;
  bool isPayButtonActive = false;
  bool isProcessing = false;
  CreditCardValidator _creditCardValidator = CreditCardValidator();

  Icon creditCardIcon = Icon(
    FontAwesomeIcons.solidCreditCard,
    color: Colors.black,
    size: 17,
  );

  BuildContext? loadingDialogContext;

  final TextEditingController _cardNumberFieldController =
      TextEditingController();
  final TextEditingController _cardMonthFieldController =
      TextEditingController();
  final TextEditingController _cardYearFieldController =
      TextEditingController();
  final TextEditingController _cardCvvFieldController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    this._cardMonthFieldController.dispose();
    this._cardYearFieldController.dispose();
    this._cardCvvFieldController.dispose();
    this._cardNumberFieldController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isPayButtonActive = cardIsValid && ccvIsValid && mMYYIsValid;
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
            appBar: FlutterwaveViewUtils.appBar(context, "Card"),
            body: Form(
              key: this._cardFormKey,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  // margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.all(10),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: double.infinity,
                          child: TextFormField(
                            decoration: InputDecoration(
                                isDense: true,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    width: 1.1,
                                    style: BorderStyle.solid,
                                    color: Colors.black,
                                  ),
                                ),
                                errorText: !cardIsValid && cardIsInValidRange
                                    ? ("Please enter a valid card number")
                                    : null,
                                suffixIcon: this
                                            ._cardNumberFieldController
                                            .text
                                            .length >
                                        0
                                    ? IconButton(
                                        icon: Icon(Icons.close),
                                        color: Colors.black,
                                        onPressed: () {
                                          setState(() {
                                            this
                                                ._cardNumberFieldController
                                                .clear();
                                            chekCCNumberInput(
                                                _cardNumberFieldController
                                                    .text);
                                            cardIsInValidRange = false;
                                            creditCardIcon = Icon(
                                              FontAwesomeIcons.solidCreditCard,
                                              size: 17,
                                              color: Colors.black,
                                            );
                                          });
                                        },
                                      )
                                    : Container(
                                        height: 0,
                                        width: 0,
                                      ),
                                prefixIcon: creditCardIcon,
                                fillColor: Colors.white,
                                hintText: 'Card Number',
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
                                )),
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            autocorrect: false,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20.0,
                            ),
                            controller: this._cardNumberFieldController,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              new CardNumberInputFormatter(),
                              new LengthLimitingTextInputFormatter(19),
                            ],

                            onChanged: (value) {
                              chekCCNumberInput(value);
                            },
                            // validator: this._validateCardField,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            // padding: const EdgeInsets.all(8.0),
                            child: Container(
                              // width: MediaQuery.of(context).size.width / 2.5,
                              // margin: EdgeInsets.fromLTRB(5, 5, 5, 5),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    isDense: true,
                                    fillColor: Colors.white,
                                    hintText: 'MM/YY',
                                    hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 15,
                                        color: Colors.black87),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        width: 1.1,
                                        style: BorderStyle.solid,
                                        color: Colors.black,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        width: 1,
                                        style: BorderStyle.none,
                                        color: Colors.black,
                                      ),
                                    ),
                                    errorText: !mMYYIsValid &&
                                            _cardYearFieldController
                                                    .text.length !=
                                                0
                                        ? ("Please enter a valid expiration date")
                                        : null,
                                    suffixIcon: this
                                                ._cardYearFieldController
                                                .text
                                                .length >
                                            0
                                        ? IconButton(
                                            icon: Icon(Icons.close),
                                            color: Colors.black,
                                            onPressed: () {
                                              setState(() {
                                                this
                                                    ._cardYearFieldController
                                                    .clear();
                                                cardIsInValidRange = false;
                                                chekCCMMYYInput(
                                                    _cardYearFieldController
                                                        .text);
                                                creditCardIcon = Icon(
                                                  FontAwesomeIcons
                                                      .solidCreditCard,
                                                  size: 17,
                                                  color: Colors.black,
                                                );
                                              });
                                            },
                                          )
                                        : Container(
                                            height: 0,
                                            width: 0,
                                          ),
                                  ),

                                  onChanged: (value) {
                                    chekCCMMYYInput(value);
                                  },

                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    new CardDateInputFormatter(),
                                    new LengthLimitingTextInputFormatter(5),
                                  ],

                                  // maxLengthEnforcement:
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.number,
                                  autocorrect: false,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20.0,
                                  ),
                                  controller: this._cardYearFieldController,
                                  // validator: this._validateCardField,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            // width: MediaQuery.of(context).size.width / 2.5,
                            // margin: EdgeInsets.fromLTRB(5, 5, 5, 5),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                decoration: InputDecoration(
                                    isDense: true,
                                    fillColor: Colors.white,
                                    hintText: 'CCV',
                                    hintStyle: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                        color: Colors.grey),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        width: 1.1,
                                        style: BorderStyle.solid,
                                        color: Colors.black,
                                      ),
                                    ),
                                    errorText: !ccvIsValid && ccvIsInRange
                                        ? ("Please enter a valid ccv")
                                        : null,
                                    suffixIcon: this
                                                ._cardCvvFieldController
                                                .text
                                                .length >
                                            0
                                        ? IconButton(
                                            icon: Icon(Icons.close),
                                            color: Colors.black,
                                            onPressed: () {
                                              setState(() {
                                                this
                                                    ._cardCvvFieldController
                                                    .clear();

                                                chekCCVInput(
                                                    _cardCvvFieldController
                                                        .text);
                                                // cardIsInValidRange = false;

                                                creditCardIcon = Icon(
                                                  FontAwesomeIcons
                                                      .solidCreditCard,
                                                  size: 17,
                                                  color: Colors.black,
                                                );
                                              });
                                            },
                                          )
                                        : Container(
                                            height: 0,
                                            width: 0,
                                          ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        width: 1,
                                        style: BorderStyle.none,
                                        color: Colors.black,
                                      ),
                                    )),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4)
                                ],
                                onChanged: (value) {
                                  chekCCVInput(value);
                                },
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                autocorrect: false,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20.0,
                                ),
                                controller: this._cardCvvFieldController,
                                // validator: (value) =>
                                //     value != null && value.isEmpty
                                //         ? "cvv is required"
                                //         : null,
                              ),
                            ),
                          ),
                        ],
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
                      )
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
                            ? isPayButtonActive
                                ? () {
                                    this._onCardFormClick();
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
                              child: !isProcessing
                                  ? Center(
                                      child: new Text(
                                        "Pay",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : SpinKitThreeBounce(
                                      size: 20,
                                      color: Colors.white,
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

  void chekCCVInput(String str) {
    if (str.length < 7 && str.length > 2) {
      setState(() {
        ccvIsInRange = true;
        ccvIsValid = true;
      });
    } else {
      setState(() {
        ccvIsValid = false;
        ccvIsInRange = false;
      });
    }
  }

  void chekCCNumberInput(String str) {
    String creditCardNumber = str.replaceAll(" ", "");
    int cardLength = creditCardNumber.length;

    if (cardLength >= 13 && cardLength <= 19) {
      var info = _creditCardValidator.validateCCNum(str);

      setState(() {
        cardIsInValidRange = true;
      });

      if (info.isValid) {
        setState(() {
          cardIsValid = true;
          CCNumValidationResults type = validateCardNumber(str);

          switch (type.ccType) {
            case CreditCardType.mastercard:
              setState(() {
                creditCardIcon =
                    Icon(FontAwesomeIcons.ccMastercard, color: Colors.black);
              });
              break;
            case CreditCardType.amex:
              setState(() {
                creditCardIcon =
                    Icon(FontAwesomeIcons.ccAmex, color: Colors.black);
              });
              break;
            case CreditCardType.visa:
              setState(() {
                creditCardIcon = Icon(
                  FontAwesomeIcons.ccVisa,
                  color: Colors.black,
                );
              });

              break;
            default:
          }
        });
      } else {
        setState(() {
          cardIsValid = false;
        });
      }
    } else if (cardLength > 19) {
      setState(() {
        cardIsInValidRange = true;
        cardIsValid = false;
      });
    } else if (cardLength < 13) {
      setState(() {
        cardIsInValidRange = false;
        cardIsValid = false;
      });
    }
  }

  void chekCCMMYYInput(String str) {
    var result = _creditCardValidator.validateExpDate(str);

    if (result.isValid) {
      setState(() {
        mMYYIsValid = true;
      });
    } else {
      setState(() {
        mMYYIsValid = false;
      });
    }
  }

  void _onCardFormClick() {
    this._hideKeyboard();

    if (this._cardFormKey.currentState!.validate()) {
      final CardPaymentManager pm = this.widget._paymentManager;
      FlutterwaveViewUtils.showConfirmPaymentModal(
          this.context, pm.currency, pm.amount, this._makeCardPayment);
    }
  }

  void _makeCardPayment() {
    Navigator.of(this.context).pop();
    this._showLoading(FlutterwaveConstants.INITIATING_PAYMENT);

    final ChargeCardRequest chargeCardRequest = ChargeCardRequest(
        cardNumber: this
            ._cardNumberFieldController
            .value
            .text
            .trim()
            .replaceAll(new RegExp(r"\s+"), ""),
        cvv: this._cardCvvFieldController.value.text.trim(),
        expiryMonth:
            this._cardYearFieldController.value.text.trim().split("/")[0],
        expiryYear:
            this._cardYearFieldController.value.text.trim().split("/")[1],
        currency: this.widget._paymentManager.currency.trim(),
        amount: this.widget._paymentManager.amount.trim(),
        email: this.widget._paymentManager.email.trim(),
        fullName: this.widget._paymentManager.fullName.trim(),
        txRef: this.widget._paymentManager.txRef.trim(),
        redirectUrl: this.widget._paymentManager.redirectUrl,
        country: this.widget._paymentManager.country);

    final client = http.Client();

    this
        .widget
        ._paymentManager
        .setCardPaymentListener(this)
        .payWithCard(client, chargeCardRequest);
  }

  String? _validateCardField(String? value) {
    return value != null && value.trim().isEmpty ? "Please fill this" : null;
  }

  void _hideKeyboard() {
    FocusScope.of(this.context).requestFocus(FocusNode());
  }

  @override
  void onRedirect(ChargeResponse chargeResponse, String url) async {
    this._closeDialog();
    final result = await Navigator.of(this.context).push(MaterialPageRoute(
        builder: (context) => AuthorizationWebview(
            Uri.encodeFull(url), this.widget._paymentManager.redirectUrl!)));
    if (result != null) {
      final bool hasError = result.runtimeType != " ".runtimeType;
      this._closeDialog();
      if (hasError) {
        this._showSnackBar(result["error"]);
        return;
      }
      final flwRef = result;
      this._showLoading(FlutterwaveConstants.VERIFYING);
      final response = await FlutterwaveAPIUtils.verifyPayment(
          flwRef,
          http.Client(),
          this.widget._paymentManager.publicKey,
          this.widget._paymentManager.isDebugMode,
          MetricManager.VERIFY_CARD_CHARGE);
      this._closeDialog();
      if (response.data!.status == FlutterwaveConstants.SUCCESSFUL ||
          response.data!.status == FlutterwaveConstants.SUCCESS) {
        this.onComplete(response);
      }
    } else {
      this._showSnackBar("Transaction cancelled");
    }
  }

  @override
  void onRequireAddress(ChargeResponse response) async {
    this._closeDialog();
    final ChargeRequestAddress addressDetails = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => RequestAddress()));
    if (addressDetails != null) {
      this._showLoading(FlutterwaveConstants.VERIFYING_ADDRESS);
      this.widget._paymentManager.addAddress(addressDetails);
      return;
    }
    this._closeDialog();
  }

  @override
  void onRequirePin(ChargeResponse response) async {
    this._closeDialog();
    final pin = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => RequestPin()));
    if (pin == null) return;
    this._showLoading(FlutterwaveConstants.AUTHENTICATING_PIN);
    this.widget._paymentManager.addPin(pin);
  }

  @override
  void onRequireOTP(ChargeResponse response, String message) async {
    this._closeDialog();
    final otp = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => RequestOTP(message)));
    if (otp == null) return;
    this._showLoading(FlutterwaveConstants.VERIFYING);
    final ChargeResponse chargeResponse =
        await this.widget._paymentManager.addOTP(otp, response.data!.flwRef!);
    this._closeDialog();
    if (chargeResponse.message == FlutterwaveConstants.CHARGE_VALIDATED) {
      this._showLoading(FlutterwaveConstants.VERIFYING);
      this._handleTransactionVerification(chargeResponse);
    } else {
      this._closeDialog();
      this._showSnackBar(chargeResponse.message!);
    }
  }

  void _handleTransactionVerification(
      final ChargeResponse chargeResponse) async {
    final verifyResponse = await FlutterwaveAPIUtils.verifyPayment(
        chargeResponse.data!.flwRef!,
        http.Client(),
        this.widget._paymentManager.publicKey,
        this.widget._paymentManager.isDebugMode,
        MetricManager.VERIFY_CARD_CHARGE);
    this._closeDialog();

    if ((verifyResponse.data!.status == FlutterwaveConstants.SUCCESS ||
            verifyResponse.data!.status == FlutterwaveConstants.SUCCESSFUL) &&
        verifyResponse.data!.txRef == this.widget._paymentManager.txRef &&
        verifyResponse.data!.amount == this.widget._paymentManager.amount) {
      this.onComplete(verifyResponse);
    } else {
      this._showSnackBar(verifyResponse.message!);
    }
  }

  @override
  void onError(String error) {
    if (this.loadingDialogContext == null) {
      // Navigator.pop(context);
      this._closeDialog();
    } else {
      this._closeDialog();
    }
    this._showSnackBar(error);
  }

  @override
  void onNoAuthRequired(ChargeResponse chargeResponse) {
    this._closeDialog();
    this._handleTransactionVerification(chargeResponse);
  }

  @override
  void onComplete(ChargeResponse chargeResponse) {
    Navigator.pop(this.context, chargeResponse);
  }

  void _showSnackBar(String message) {
    SnackBar snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
      ),
    );
    this._scaffoldKey.currentState?.showSnackBar(snackBar);
  }

  void _showLoading(String message) {
    setState(() {
      isProcessing = true;
    });
  }

  void _closeDialog() {
    setState(() {
      isProcessing = false;
    });
  }
}

class CardDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = new StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: new TextSelection.collapsed(offset: string.length));
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = new StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(" "); // Add double spaces.
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: new TextSelection.collapsed(offset: string.length));
  }
}
