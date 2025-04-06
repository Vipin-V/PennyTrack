import "package:flow/l10n/flow_localizations.dart";
import "package:flow/routes/preferences/sections/sms_parsing.dart";
import "package:flutter/material.dart";

class SmsBankTransactionParsingPage extends StatelessWidget {
  const SmsBankTransactionParsingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SMS Bank Transactions")),
      body: const SafeArea(
        child: SingleChildScrollView(child: SmsParsingSectionPreference()),
      ),
    );
  }
}
