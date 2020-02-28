import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show FocusNode;

import 'text_input.dart';

@immutable
class AutofillConfiguration {
  const AutofillConfiguration({
    @required this.uniqueIdentifier,
    @required this.autofillHints,
    this.currentEditingValue,
  }) : assert(uniqueIdentifier != null),
       assert(autofillHints != null);

  final String uniqueIdentifier;
  final List<String> autofillHints;
  final TextEditingValue currentEditingValue;

  /// Returns a representation of this object as a JSON object.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uniqueIdentifier': uniqueIdentifier,
      'hints': autofillHints,
      'editingValue': currentEditingValue.toJSON(),
    };
  }
}

// Ideally AutofillClient should NOT extend TextInputClient. Rather, TextInputClient
// should have an `AutofillDelegate` property.
abstract class AutofillClient extends TextInputClient {
  TextInputConfiguration get textInputConfiguration;

  String get uniqueIdentifier;

  AutofillScope get currentAutofillScope;

  FocusNode get focusNode;
  //TextEditingValue get currentTextEditingValue;
  //void updateEditingValue(TextEditingValue value);
}

mixin AutofillClientMixin implements AutofillClient {
  @override
  String get uniqueIdentifier {
    final String identifier = textInputConfiguration.autofillConfiguration?.uniqueIdentifier;
    assert(identifier != null);
    return identifier;
  }
}

abstract class AutofillScope {
  AutofillClient getAutofillClient(String tag);

  // Updating TextInputConfiguration is not needed as far as autofill goes,
  // because changing focus is the only way to trigger autofill.
  //void updateTextInputConfigurationIfNeeded();
  //void markNeedsTextInputConfigurationUpdate();
}

@immutable
class _AutofillScopeTextInputConfiguration extends TextInputConfiguration {
  _AutofillScopeTextInputConfiguration({
    @required this.allConfigurations,
    @required TextInputConfiguration currentClientConfiguration,
  }) : assert(allConfigurations != null),
       assert(currentClientConfiguration != null),
       super(inputType: currentClientConfiguration.inputType,
         obscureText: currentClientConfiguration.obscureText,
         autocorrect: currentClientConfiguration.autocorrect,
         smartDashesType: currentClientConfiguration.smartDashesType,
         smartQuotesType: currentClientConfiguration.smartQuotesType,
         enableSuggestions: currentClientConfiguration.enableSuggestions,
         inputAction: currentClientConfiguration.inputAction,
         textCapitalization: currentClientConfiguration.textCapitalization,
         keyboardAppearance: currentClientConfiguration.keyboardAppearance,
         actionLabel: currentClientConfiguration.actionLabel,
         autofillConfiguration: currentClientConfiguration.autofillConfiguration,
       );

  final Iterable<TextInputConfiguration> allConfigurations;

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = super.toJson();
    result['allFields'] = allConfigurations
      .map((TextInputConfiguration configuration) => configuration.toJson())
      .toList(growable: false);
    return result;
  }
}

mixin AutofillScopeMixin implements AutofillScope {
  //bool _needsTextInputConfigurationUpdate = false;
  TextInputConnection _textInputConnection;
  //String _currentClientTag;
  //AutofillClient get _currentClient => _currentClientTag == null ? null : _clients[_currentClientTag];
  final Map<String, AutofillClient> _clients = <String, AutofillClient>{};

  @protected
  void registerAutofillClient(AutofillClient client) {
    final String identifier = client.uniqueIdentifier;
    assert(identifier != null);
    _clients.putIfAbsent(identifier, ()=>client);
  }

  @protected
  void unregisterAutofillClient(String identifier) {
    _clients.remove(identifier);
  }

  @override
  AutofillClient getAutofillClient(String tag) => _clients[tag];

  @protected
  Iterable<AutofillClient> sortClients(Iterable<AutofillClient> clients) => throw UnimplementedError();

  TextInputConnection attach(AutofillClient client) {
    assert(client != null);

    _textInputConnection = TextInput.attach(
      client,
      _AutofillScopeTextInputConfiguration(
        allConfigurations: sortClients(_clients.values)
          .map((AutofillClient client) => client.textInputConfiguration),
        currentClientConfiguration: client.textInputConfiguration,
      ),
    );
    //_currentClientTag = client.uniqueIdentifier;
    return _textInputConnection;
  }

  //@override
  //void updateTextInputConfigurationIfNeeded() {
  //  if (!_needsTextInputConfigurationUpdate)
  //    return;
  //  if (_textInputConnection?.attached ?? false) {
  //    final TextInputConfiguration newConfiguration = _AutofillScopeTextInputConfiguration(
  //      allConfigurations: _clients.values.map((AutofillClient client) => client.textInputConfiguration),
  //      currentClientConfiguration: _currentClient.textInputConfiguration,
  //    );
  //    _textInputConnection.updateTextInputConfiguration(newConfiguration);
  //  }
  //  _needsTextInputConfigurationUpdate = false;
  //}

  //@override
  //void markNeedsTextInputConfigurationUpdate() {
  //  // No need to update if the connection is closed because the configuration is
  //  // also updated on connection open.
  //  _needsTextInputConfigurationUpdate = _textInputConnection?.attached ?? false;
  //}
}
