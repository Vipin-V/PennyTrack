import "package:flow/l10n/flow_localizations.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/services/sms_parser.dart";
import "package:flow/widgets/general/list_header.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:permission_handler/permission_handler.dart";

class SmsParsingSectionPreference extends StatefulWidget {
  const SmsParsingSectionPreference({super.key});

  @override
  State<SmsParsingSectionPreference> createState() =>
      _SmsParsingSectionPreferenceState();
}

class _SmsParsingSectionPreferenceState
    extends State<SmsParsingSectionPreference> {
  bool _smsPermissionGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSmsPermission();
  }

  Future<void> _checkSmsPermission() async {
    setState(() {
      _isLoading = true;
    });

    final status = await Permission.sms.status;
    setState(() {
      _smsPermissionGranted = status.isGranted;
      _isLoading = false;
    });
  }

  Future<void> _requestSmsPermission() async {
    setState(() {
      _isLoading = true;
    });

    final status = await Permission.sms.request();

    setState(() {
      _smsPermissionGranted = status.isGranted;
      _isLoading = false;
    });

    if (status.isGranted) {
      // If user grants permission, enable SMS parsing
      LocalPreferences().enableSmsParsing.set(true);
      await SmsParserService().initialize();
      await SmsParserService().processPendingSms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enableSmsParsing = LocalPreferences().enableSmsParsing.get();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16.0),
        ListHeader("SMS Bank Transaction Parsing"),
        const SizedBox(height: 8.0),
        SwitchListTile(
          title: Text("Enable SMS Parsing"),
          subtitle: Text(
            "Automatically detect and add transactions from bank SMS messages",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          value: enableSmsParsing,
          onChanged:
              _isLoading
                  ? null
                  : (value) async {
                    if (value && !_smsPermissionGranted) {
                      await _requestSmsPermission();
                    } else {
                      LocalPreferences().enableSmsParsing.set(value);
                      if (value) {
                        await SmsParserService().initialize();
                        await SmsParserService().processPendingSms();
                      }
                      setState(() {});
                    }
                  },
          secondary:
              _isLoading
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(
                    enableSmsParsing
                        ? Symbols.sms_rounded
                        : Symbols.sms_failed_rounded,
                  ),
        ),
        if (!_smsPermissionGranted && enableSmsParsing)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Symbols.warning_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          "Permission Required",
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "SMS permission is required to read bank messages",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    OutlinedButton.icon(
                      icon: const Icon(Symbols.settings_applications_rounded),
                      label: const Text("Grant Permission"),
                      onPressed: _requestSmsPermission,
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onErrorContainer,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This feature will:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.0),
              Text("• Automatically read SMS messages from banks"),
              Text("• Detect credit and debit transactions"),
              Text("• Add them to your accounts as income or expenses"),
              SizedBox(height: 16.0),
              Text(
                "Supported Banks:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.0),
              Text("• HDFC Bank"),
              Text("• ICICI Bank"),
              Text("• SBI"),
              Text("• And more..."),
            ],
          ),
        ),
      ],
    );
  }
}
