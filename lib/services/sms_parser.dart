import "dart:async";

import "package:flow/entity/account.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/logging.dart";
import "package:flow/objectbox.dart";
import "package:flow/services/transactions.dart";
import "package:flutter/foundation.dart";
import "package:flutter_sms_inbox/flutter_sms_inbox.dart" as sms_inbox;
import "package:permission_handler/permission_handler.dart";
import "package:telephony/telephony.dart";
import "package:logging/logging.dart";

final _smsLogger = Logger("SmsParser");

class SmsParserService with ChangeNotifier {
  static final SmsParserService _instance = SmsParserService._internal();
  factory SmsParserService() => _instance;

  final sms_inbox.SmsQuery _query = sms_inbox.SmsQuery();
  final Telephony _telephony = Telephony.instance;
  final List<BankSmsPattern> _bankPatterns = [];
  Timer? _refreshTimer;
  bool _isInitialized = false;
  DateTime _lastSmsProcessTime = DateTime(2000); // Start with old date

  SmsParserService._internal() {
    _bankPatterns.addAll([
      // Add different bank patterns here
      // HDFC Bank pattern
      BankSmsPattern(
        senderPattern: RegExp(r"HDFCBANK|HDFC-BANK", caseSensitive: false),
        creditPattern: RegExp(
          r"(?:credited|deposit|received|added).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"(?:debited|spent|payment|withdrawn|deducted|paid|purchase).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"(?:Info|Info:|at|in|to|from|trf\s+to)\s+([A-Za-z0-9\s\-\&\.\*]+)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:a\/c|ac|acct)\s*(?:no\.?|number)?\s*[xX\*]*(\d+)",
          caseSensitive: false,
        ),
      ),
      // ICICI Bank pattern
      BankSmsPattern(
        senderPattern: RegExp(
          r"ICICIBANK|ICICI-BANK|ICICIB",
          caseSensitive: false,
        ),
        creditPattern: RegExp(
          r"(?:credited|deposit|received|added).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"(?:debited|spent|payment|withdrawn|deducted|paid|purchase).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"(?:Info|Info:|at|in|to|from|trf\s+to)\s+([A-Za-z0-9\s\-\&\.\*]+)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:a\/c|ac|acct)\s*(?:no\.?|number)?\s*[xX\*]*(\d+)",
          caseSensitive: false,
        ),
      ),
      // SBI Bank pattern
      BankSmsPattern(
        senderPattern: RegExp(r"SBIBANK|SBI|SBIATM", caseSensitive: false),
        creditPattern: RegExp(
          r"(?:credited|deposit|received|added|has credit).+?(?:Rs\.?|INR|of Rs)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"(?:debited|spent|payment|purchase|withdrawn|deducted|paid).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"(?:Info|Info:|at|in|to|from|trf\s+to)\s+([A-Za-z0-9\s\-\&\.\*]+)|(?:UPI\/[A-Z]+\/)(\d+)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:a\/c|ac|acct|A\/C)\s*(?:no\.?|number)?\s*[xX\*]*([\dX]+)",
          caseSensitive: false,
        ),
      ),
      // Indian Bank pattern
      BankSmsPattern(
        senderPattern: RegExp(r"INDIAN BANK|INDIANB", caseSensitive: false),
        creditPattern: RegExp(
          r"Rs\.?([\d,]+\.?\d*)\s*credited|credited\s*Rs\.?\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"(?:debited)\s*Rs\.?\s*([\d,]+\.?\d*)|Rs\.?([\d,]+\.?\d*)\s*debited",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"(?:UPI Ref no|UPI:)\s*([\d]+)|to\s+([A-Za-z0-9\s\-\&\.\*]+)|VPA\s+([A-Za-z0-9\s\-\&\.\*@]+)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:a\/c|ac|acct)\s*(?:\*|no\.?|number)?\s*([\d]+)",
          caseSensitive: false,
        ),
      ),
      // Federal Bank pattern
      BankSmsPattern(
        senderPattern: RegExp(r"FEDERAL|FEDERAL BANK", caseSensitive: false),
        creditPattern: RegExp(
          r"Rs\.?([\d,]+\.?\d*)\s*credited|Rs\.?([\d,]+)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"Rs\s*([\d,]+\.?\d*)\s*debited|Rs\.?([\d,]+\.?\d*)\s*debited",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"(?:Ref No|UPI)\s+([\d]+)|to\s+VPA\s+([A-Za-z0-9\s\-\&\.\*@]+)|BAL-Rs\.([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:A\/c|a\/c)\s*(?:XX|no\.?|number)?\s*([\dX]+)",
          caseSensitive: false,
        ),
      ),
      // Kerala Gramin Bank pattern
      BankSmsPattern(
        senderPattern: RegExp(r"KERALA|GRAMIN|KGB", caseSensitive: false),
        creditPattern: RegExp(
          r"(?:credited with INR|credited).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)|(?:credited to a\/c)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"(?:debited for|debited|spent|payment|withdrawn|deducted).+?(?:Rs\.?|INR)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"(?:UPI Ref\.? no\.?|Ref\.? no\.?|Ref|trf\s+to)\s+([A-Za-z0-9\s\-\&\.\*]+)|(?:-|\()([A-Za-z0-9\s\-\&\.\*]+)(?:\)|$)|from\s+([A-Za-z0-9\s\-\&\.\*@]+)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:a\/c|ac|acct|Account)\s*(?:no\.?|number)?\s*[xX\*]*([\dX]+)",
          caseSensitive: false,
        ),
      ),
      // Central Bank of India pattern
      BankSmsPattern(
        senderPattern: RegExp(r"CBoI|CENTRAL BANK|CENTRAL BANK OF INDIA", caseSensitive: false),
        creditPattern: RegExp(
          r"(?:credited by Rs\.?|credited)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        debitPattern: RegExp(
          r"(?:debited by Rs\.?|debited)\s*([\d,]+\.?\d*)",
          caseSensitive: false,
        ),
        descriptionPattern: RegExp(
          r"Total Bal:\s*Rs\.?\s*([\d,]+\.?\d*)|(?:-|\()([A-Za-z0-9\s\-\&\.\*]+)(?:\)|$)",
          caseSensitive: false,
        ),
        accountNumberPattern: RegExp(
          r"(?:A\/c|a\/c)\s*([\dxX]+)",
          caseSensitive: false,
        ),
      ),
      // Add more bank patterns as needed
    ]);
  }

  /// Initializes the SMS parser service and requests necessary permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request SMS permissions
      final status = await Permission.sms.request();
      if (status.isDenied) {
        _smsLogger.warning("SMS permission denied by user");
        return false;
      }

      // Set up background message handler
      _telephony.listenIncomingSms(
        onNewMessage: _onNewMessage,
        onBackgroundMessage: _backgroundMessageHandler,
      );

      // Start periodic refresh (every 30 minutes)
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 30),
        (_) => processPendingSms(),
      );

      _isInitialized = true;
      _smsLogger.info("SMS parser service initialized successfully");
      return true;
    } catch (e) {
      _smsLogger.severe("Failed to initialize SMS parser service", e);
      return false;
    }
  }

  /// Process new SMS messages received while the app is running
  void _onNewMessage(SmsMessage message) {
    // Create equivalent SmsMessage from Telephony plugin message
    final address = message.address ?? "";
    final body = message.body ?? "";
    final date = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(message.date?.toString() ?? "0") ?? 0,
    );
    _processIncomingSmsMessage(address, body, date);
  }

  /// Process any pending SMS messages that haven't been processed yet
  Future<void> processPendingSms() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    try {
      // Get messages after the last processed time
      final messages = await _query.querySms(
        kinds: [sms_inbox.SmsQueryKind.inbox],
        count: 20,
        sort: true,
      );

      if (messages.isEmpty) return;

      final DateTime newestMessageTime = messages
          .map((msg) => msg.date ?? DateTime.now())
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // Only process messages received after the last processing time
      for (final message in messages) {
        if ((message.date ?? DateTime.now()).isAfter(_lastSmsProcessTime)) {
          await _processMessage(message);
        }
      }

      // Update the last process time
      _lastSmsProcessTime = newestMessageTime;
      notifyListeners();
    } catch (e) {
      _smsLogger.severe("Error processing pending SMS messages", e);
    }
  }

  /// Process an incoming SMS directly from the telephony plugin
  Future<void> _processIncomingSmsMessage(
    String sender,
    String body,
    DateTime date,
  ) async {
    if (sender.isEmpty || body.isEmpty) return;

    // Find matching bank pattern
    for (final pattern in _bankPatterns) {
      if (pattern.senderPattern.hasMatch(sender)) {
        _smsLogger.fine("Found matching bank SMS from: $sender");

        // Extract transaction details
        final transaction = _extractTransaction(body, pattern);

        if (transaction != null) {
          await _saveTransaction(transaction, sender);
        }

        break;
      }
    }
  }

  /// Process a single SMS message and extract transaction data if it's a bank message
  Future<void> _processMessage(sms_inbox.SmsMessage message) async {
    final sender = message.address;
    final body = message.body;

    if (sender == null || body == null) return;

    await _processIncomingSmsMessage(
      sender,
      body,
      message.date ?? DateTime.now(),
    );
  }

  /// Extract transaction details from SMS body using provided pattern
  _BankTransaction? _extractTransaction(String body, BankSmsPattern pattern) {
    try {
      _smsLogger.fine("Attempting to extract transaction from SMS: ${body.substring(0, body.length > 50 ? 50 : body.length)}...");
      
      // Special case for Kerala Gramin Bank format
      if (body.contains("Kerala Gramin Bank") || 
          body.contains("KGB") || 
          body.contains("KERALA GRAMIN")) {
        // Try to extract amount directly with a specific pattern for Kerala Gramin Bank
        final kgbDebitPattern = RegExp(r"debited for Rs\.(\d+\.?\d*)", caseSensitive: false);
        final kgbDebitMatch = kgbDebitPattern.firstMatch(body);
        
        if (kgbDebitMatch != null && kgbDebitMatch.groupCount >= 1) {
          final amountStr = kgbDebitMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Kerala Gramin Bank debit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Kerala Gramin Bank debit of amount: $amount");
            return _BankTransaction(
              amount: -amount, // Negative amount for debits
              isCredit: false,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
        
        // Check for credited with INR pattern
        final kgbCreditPattern = RegExp(r"credited with INR (\d+\.?\d*)", caseSensitive: false);
        final kgbCreditMatch = kgbCreditPattern.firstMatch(body);
        
        if (kgbCreditMatch != null && kgbCreditMatch.groupCount >= 1) {
          final amountStr = kgbCreditMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Kerala Gramin Bank credit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Kerala Gramin Bank credit of amount: $amount");
            return _BankTransaction(
              amount: amount,
              isCredit: true,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
      }
      
      // Special case for Federal Bank format
      if (body.contains("Federal Bank")) {
        // Try direct patterns for Federal Bank
        final fedDebitPattern = RegExp(r"Rs\s*(\d+\.?\d*)\s*debited", caseSensitive: false);
        final fedDebitMatch = fedDebitPattern.firstMatch(body);
        
        if (fedDebitMatch != null && fedDebitMatch.groupCount >= 1) {
          final amountStr = fedDebitMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Federal Bank debit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Federal Bank debit of amount: $amount");
            return _BankTransaction(
              amount: -amount, // Negative amount for debits
              isCredit: false,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
        
        // Check for credit pattern
        final fedCreditPattern = RegExp(r"Rs\.(\d+)\s*credited", caseSensitive: false);
        final fedCreditMatch = fedCreditPattern.firstMatch(body);
        
        if (fedCreditMatch != null && fedCreditMatch.groupCount >= 1) {
          final amountStr = fedCreditMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Federal Bank credit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Federal Bank credit of amount: $amount");
            return _BankTransaction(
              amount: amount,
              isCredit: true,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
      }
      
      // Special case for Central Bank of India format
      if (body.contains("CBoI") || body.contains("Central Bank")) {
        // Try direct patterns for Central Bank of India
        final cboiDebitPattern = RegExp(r"debited by Rs\.\s*(\d+,?\d*\.?\d*)", caseSensitive: false);
        final cboiDebitMatch = cboiDebitPattern.firstMatch(body);
        
        if (cboiDebitMatch != null && cboiDebitMatch.groupCount >= 1) {
          final amountStr = cboiDebitMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Central Bank of India debit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Central Bank of India debit of amount: $amount");
            return _BankTransaction(
              amount: -amount, // Negative amount for debits
              isCredit: false,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
        
        // Check for credit pattern
        final cboiCreditPattern = RegExp(r"credited by Rs\.\s*(\d+,?\d*\.?\d*)", caseSensitive: false);
        final cboiCreditMatch = cboiCreditPattern.firstMatch(body);
        
        if (cboiCreditMatch != null && cboiCreditMatch.groupCount >= 1) {
          final amountStr = cboiCreditMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Central Bank of India credit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Central Bank of India credit of amount: $amount");
            return _BankTransaction(
              amount: amount,
              isCredit: true,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
      }
      
      // Special case for SBI format
      if (body.contains("-SBI") || body.contains("SBI")) {
        // Try direct patterns for SBI
        final sbiCreditPattern = RegExp(r"has credit.+?of Rs\s*(\d+\.?\d*)", caseSensitive: false);
        final sbiCreditMatch = sbiCreditPattern.firstMatch(body);
        
        if (sbiCreditMatch != null && sbiCreditMatch.groupCount >= 1) {
          final amountStr = sbiCreditMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found SBI credit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted SBI credit of amount: $amount");
            return _BankTransaction(
              amount: amount,
              isCredit: true,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
      }
      
      // Special case for Indian Bank format
      if (body.contains("Indian Bank")) {
        // Try direct patterns for Indian Bank
        final indianBankDebitPattern = RegExp(r"debited Rs\.\s*(\d+\.?\d*)", caseSensitive: false);
        final indianBankDebitMatch = indianBankDebitPattern.firstMatch(body);
        
        if (indianBankDebitMatch != null && indianBankDebitMatch.groupCount >= 1) {
          final amountStr = indianBankDebitMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Indian Bank debit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Indian Bank debit of amount: $amount");
            return _BankTransaction(
              amount: -amount, // Negative amount for debits
              isCredit: false,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
        
        // Check for credit pattern
        final indianBankCreditPattern = RegExp(r"Rs\.(\d+\.?\d*)\s*credited", caseSensitive: false);
        final indianBankCreditMatch = indianBankCreditPattern.firstMatch(body);
        
        if (indianBankCreditMatch != null && indianBankCreditMatch.groupCount >= 1) {
          final amountStr = indianBankCreditMatch.group(1)?.replaceAll(",", "") ?? "0";
          _smsLogger.fine("Found Indian Bank credit amount: $amountStr");
          final double amount = double.tryParse(amountStr) ?? 0;
          
          if (amount > 0) {
            _smsLogger.info("Successfully extracted Indian Bank credit of amount: $amount");
            return _BankTransaction(
              amount: amount,
              isCredit: true,
              description: _extractDescription(body, pattern),
              accountNumber: _extractAccountNumber(body, pattern),
              rawMessage: body,
            );
          }
        }
      }
      
      // Check for credit transaction
      final creditMatch = pattern.creditPattern.firstMatch(body);
      if (creditMatch != null && creditMatch.groupCount >= 1) {
        final amountStr = creditMatch.group(1)?.replaceAll(",", "") ?? "0";
        _smsLogger.fine("Found credit amount string: $amountStr");
        final double amount = double.tryParse(amountStr) ?? 0;

        if (amount > 0) {
          _smsLogger.info("Successfully extracted credit transaction of amount: $amount");
          return _BankTransaction(
            amount: amount,
            isCredit: true,
            description: _extractDescription(body, pattern),
            accountNumber: _extractAccountNumber(body, pattern),
            rawMessage: body,
          );
        }
      }

      // Check for debit transaction
      final debitMatch = pattern.debitPattern.firstMatch(body);
      if (debitMatch != null && debitMatch.groupCount >= 1) {
        final amountStr = debitMatch.group(1)?.replaceAll(",", "") ?? "0";
        _smsLogger.fine("Found debit amount string: $amountStr");
        final double amount = double.tryParse(amountStr) ?? 0;

        if (amount > 0) {
          _smsLogger.info("Successfully extracted debit transaction of amount: $amount");
          return _BankTransaction(
            amount: -amount, // Negative amount for debits
            isCredit: false,
            description: _extractDescription(body, pattern),
            accountNumber: _extractAccountNumber(body, pattern),
            rawMessage: body,
          );
        }
      } else {
        _smsLogger.warning("No transaction amount found in SMS: ${body.substring(0, body.length > 50 ? 50 : body.length)}...");
      }
    } catch (e) {
      _smsLogger.warning("Error extracting transaction details", e);
    }

    return null;
  }

  /// Extract description from the SMS body
  String _extractDescription(String body, BankSmsPattern pattern) {
    final match = pattern.descriptionPattern.firstMatch(body);
    // Check all possible capture groups (for patterns with multiple capture groups)
    final description = match?.group(1)?.trim() ?? 
                       match?.group(2)?.trim() ?? 
                       match?.group(3)?.trim() ?? 
                       "Bank Transaction";
    _smsLogger.fine("Extracted description: $description");
    return description;
  }

  /// Extract account number from the SMS body
  String? _extractAccountNumber(String body, BankSmsPattern pattern) {
    final match = pattern.accountNumberPattern.firstMatch(body);
    return match?.group(1);
  }

  /// Save the extracted transaction to the database
  Future<void> _saveTransaction(
    _BankTransaction bankTransaction,
    String sender,
  ) async {
    try {
      _smsLogger.info("Saving transaction: ${bankTransaction.amount} from sender: $sender");
      
      // Find matching account
      Account? targetAccount;

      // Get all accounts
      final accounts = ObjectBox().box<Account>().getAll();

      if (accounts.isEmpty) {
        _smsLogger.warning("No accounts found in the database");
        return;
      }

      // Try to find matching account by bank name from sender
      final bankName = _extractBankName(sender);
      _smsLogger.fine("Extracted bank name: $bankName");

      targetAccount = accounts.firstWhere(
        (account) =>
            account.name.toLowerCase().contains(bankName.toLowerCase()),
        orElse: () => accounts.first,
      );
      
      _smsLogger.fine("Using account: ${targetAccount.name}");

      // Create transaction
      final transaction = Transaction(
        uuid: DateTime.now().microsecondsSinceEpoch.toString(),
        amount: bankTransaction.amount,
        currency: targetAccount.currency,
        title:
            bankTransaction.isCredit
                ? "Income: ${bankTransaction.description}"
                : "Expense: ${bankTransaction.description}",
        description:
            "Automatically added from SMS: ${bankTransaction.rawMessage.substring(0, bankTransaction.rawMessage.length > 100 ? 100 : bankTransaction.rawMessage.length)}...",
        createdDate: DateTime.now(),
      );

      transaction.setAccount(targetAccount);

      // Save transaction using TransactionsService
      await TransactionsService().upsertOne(transaction);
      _smsLogger.info(
        'Added new ${bankTransaction.isCredit ? "income" : "expense"} '
        "transaction of ${bankTransaction.amount.abs()} ${targetAccount.currency}",
      );
    } catch (e) {
      _smsLogger.severe("Error saving transaction from SMS", e);
    }
  }

  /// Extract bank name from the sender information
  String _extractBankName(String sender) {
    if (sender.toUpperCase().contains("HDFC")) return "HDFC";
    if (sender.toUpperCase().contains("ICICI")) return "ICICI";
    if (sender.toUpperCase().contains("SBI")) return "SBI";
    if (sender.toUpperCase().contains("KERALA") || 
        sender.toUpperCase().contains("GRAMIN") || 
        sender.toUpperCase().contains("KGB")) return "Kerala Gramin Bank";
    if (sender.toUpperCase().contains("CBOI") || 
        sender.toUpperCase().contains("CENTRAL BANK")) return "Central Bank of India";
    if (sender.toUpperCase().contains("INDIAN BANK")) return "Indian Bank";
    if (sender.toUpperCase().contains("FEDERAL")) return "Federal Bank";
    // Add more banks as needed
    return "Bank";
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Background message handler (needed for telephony plugin)
@pragma("vm:entry-point")
void _backgroundMessageHandler(SmsMessage message) {
  // This will just receive the message, and the app will process it
  // during the next refresh cycle or when the app is opened
  _smsLogger.fine("Received SMS in background handler");
}

/// Model class to store bank SMS patterns
class BankSmsPattern {
  final RegExp senderPattern;
  final RegExp creditPattern;
  final RegExp debitPattern;
  final RegExp descriptionPattern;
  final RegExp accountNumberPattern;

  BankSmsPattern({
    required this.senderPattern,
    required this.creditPattern,
    required this.debitPattern,
    required this.descriptionPattern,
    required this.accountNumberPattern,
  });
}

/// Model class to store extracted transaction details
class _BankTransaction {
  final double amount;
  final bool isCredit;
  final String description;
  final String? accountNumber;
  final String rawMessage;

  _BankTransaction({
    required this.amount,
    required this.isCredit,
    required this.description,
    this.accountNumber,
    required this.rawMessage,
  });
}
