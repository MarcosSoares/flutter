// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../base/context.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../base/user_messages.dart';
import '../base/version.dart';
import '../doctor.dart';
import 'cocoapods.dart';
import 'mac.dart';
import 'plist_utils.dart' as plist;

IOSWorkflow get iosWorkflow => context[IOSWorkflow];
IOSValidator get iosValidator => context[IOSValidator];
CocoaPodsValidator get cocoapodsValidator => context[CocoaPodsValidator];

class IOSWorkflow implements Workflow {
  const IOSWorkflow();

  @override
  bool get appliesToHostPlatform => platform.isMacOS;

  // We need xcode (+simctl) to list simulator devices, and libimobiledevice to list real devices.
  @override
  bool get canListDevices => xcode.isInstalledAndMeetsVersionCheck && xcode.isSimctlInstalled;

  // We need xcode to launch simulator devices, and ideviceinstaller and ios-deploy
  // for real devices.
  @override
  bool get canLaunchDevices => xcode.isInstalledAndMeetsVersionCheck;

  @override
  bool get canListEmulators => false;

  String getPlistValueFromFile(String path, String key) {
    return plist.getValueFromFile(path, key);
  }
}

class IOSValidator extends DoctorValidator {

  const IOSValidator() : super('iOS toolchain - develop for iOS devices');

  Future<bool> get hasIDeviceInstaller => exitsHappyAsync(<String>['ideviceinstaller', '-h']);

  Future<bool> get hasIosDeploy => exitsHappyAsync(<String>['ios-deploy', '--version']);

  String get iosDeployMinimumVersion => '1.9.2';

  Future<String> get iosDeployVersionText async => (await runAsync(<String>['ios-deploy', '--version'])).processResult.stdout.replaceAll('\n', '');

  bool get hasHomebrew => os.which('brew') != null;

  Future<String> get macDevMode async => (await runAsync(<String>['DevToolsSecurity', '-status'])).processResult.stdout;

  Future<bool> get _iosDeployIsInstalledAndMeetsVersionCheck async {
    if (!await hasIosDeploy)
      return false;
    try {
      final Version version = Version.parse(await iosDeployVersionText);
      return version >= Version.parse(iosDeployMinimumVersion);
    } on FormatException catch (_) {
      return false;
    }
  }

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];
    ValidationType xcodeStatus = ValidationType.missing;
    ValidationType brewStatus = ValidationType.missing;
    String xcodeVersionInfo;

    if (xcode.isInstalled) {
      xcodeStatus = ValidationType.installed;

      messages.add(ValidationMessage(userMessages.iOSXcodeLocation(xcode.xcodeSelectPath)));

      xcodeVersionInfo = xcode.versionText;
      if (xcodeVersionInfo.contains(','))
        xcodeVersionInfo = xcodeVersionInfo.substring(0, xcodeVersionInfo.indexOf(','));
      messages.add(ValidationMessage(xcode.versionText));

      if (!xcode.isInstalledAndMeetsVersionCheck) {
        xcodeStatus = ValidationType.partial;
        messages.add(ValidationMessage.error(
            userMessages.iOSXcodeOutdated(kXcodeRequiredVersionMajor, kXcodeRequiredVersionMinor)
        ));
      }

      if (!xcode.eulaSigned) {
        xcodeStatus = ValidationType.partial;
        messages.add(ValidationMessage.error(userMessages.iOSXcodeEula));
      }
      if (!xcode.isSimctlInstalled) {
        xcodeStatus = ValidationType.partial;
        messages.add(ValidationMessage.error(userMessages.iOSXcodeMissingSimct));
      }

    } else {
      xcodeStatus = ValidationType.missing;
      if (xcode.xcodeSelectPath == null || xcode.xcodeSelectPath.isEmpty) {
        messages.add(ValidationMessage.error(userMessages.iOSXcodeMissing));
      } else {
        messages.add(ValidationMessage.error(userMessages.iOSXcodeIncomplete));
      }
    }

    // brew installed
    if (hasHomebrew) {
      brewStatus = ValidationType.installed;

      if (!iMobileDevice.isInstalled) {
        brewStatus = ValidationType.partial;
        messages.add(ValidationMessage.error(userMessages.iOSIMobileDeviceMissing));
      } else if (!await iMobileDevice.isWorking) {
        brewStatus = ValidationType.partial;
        messages.add(ValidationMessage.error(userMessages.iOSIMobileDeviceBroken));
      } else if (!await hasIDeviceInstaller) {
        brewStatus = ValidationType.partial;
        messages.add(ValidationMessage.error(userMessages.iOSDeviceInstallerMissing));
      }

      // Check ios-deploy is installed at meets version requirements.
      if (await hasIosDeploy) {
        messages.add(ValidationMessage(userMessages.iOSDeployVersion(await iosDeployVersionText)));
      }
      if (!await _iosDeployIsInstalledAndMeetsVersionCheck) {
        brewStatus = ValidationType.partial;
        if (await hasIosDeploy) {
          messages.add(ValidationMessage.error(userMessages.iOSDeployOutdated(iosDeployMinimumVersion)));
        } else {
          messages.add(ValidationMessage.error(userMessages.iOSDeployMissing));
        }
      }

    } else {
      brewStatus = ValidationType.missing;
      messages.add(ValidationMessage.error(userMessages.iOSBrewMissing));
    }

    return ValidationResult(
        <ValidationType>[xcodeStatus, brewStatus].reduce(_mergeValidationTypes),
        messages,
        statusInfo: xcodeVersionInfo
    );
  }

  ValidationType _mergeValidationTypes(ValidationType t1, ValidationType t2) {
    return t1 == t2 ? t1 : ValidationType.partial;
  }
}

class CocoaPodsValidator extends DoctorValidator {
  const CocoaPodsValidator() : super('CocoaPods subvalidator');

  bool get hasHomebrew => os.which('brew') != null;

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    ValidationType status = ValidationType.installed;
    if (hasHomebrew) {
      final CocoaPodsStatus cocoaPodsStatus = await cocoaPods
          .evaluateCocoaPodsInstallation;

      if (cocoaPodsStatus == CocoaPodsStatus.recommended) {
        if (await cocoaPods.isCocoaPodsInitialized) {
          messages.add(ValidationMessage(userMessages.cocoaPodsVersion(await cocoaPods.cocoaPodsVersionText)));
        } else {
          status = ValidationType.partial;
          messages.add(ValidationMessage.error(userMessages.cocoaPodsUninitialized));
        }
      } else {
        if (cocoaPodsStatus == CocoaPodsStatus.notInstalled) {
          status = ValidationType.missing;
          messages.add(ValidationMessage.error(userMessages.cocoaPodsMissing));
        } else {
          status = ValidationType.partial;
          messages.add(ValidationMessage.hint(
              userMessages.cocoaPodsOutdated(cocoaPods.cocoaPodsRecommendedVersion)));
        }
      }
    } else {
      // Only set status. The main validator handles messages for missing brew.
      status = ValidationType.missing;
    }
    return ValidationResult(status, messages);
  }
}
