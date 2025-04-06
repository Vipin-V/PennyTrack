import "dart:io";

import "package:flow/constants.dart";
import "package:flow/data/flow_icon.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/theme/theme.dart";
import "package:flow/utils/utils.dart";
import "package:flow/widgets/action_card.dart";
import "package:flow/widgets/general/button.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";

class SupportPage extends StatelessWidget {
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 24.0,
  );

  static const ShapeBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16.0)),
  );

  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("support".t(context))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("support.description".t(context)),
              const SizedBox(height: 16.0),




              if (!(Platform.isIOS || Platform.isMacOS)) ...[
                const SizedBox(height: 16.0),
                ActionCard(
                  title: "support.donateDeveloper".t(context),
                  subtitle: "support.donateDeveloper.description".t(context),
                  icon: FlowIconData.icon(Symbols.favorite_rounded),
                  trailing: Button(
                    backgroundColor: context.colorScheme.surface,
                    trailing: const Icon(Symbols.chevron_right_rounded),
                    child: Expanded(
                      child: Text("support.donateDeveloper.action".t(context)),
                    ),
                    onTap: () => openUrl(maintainerKoFiLink),
                  ),
                ),
              ],
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }


}
