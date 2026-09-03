import Contacts
import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.example.counter.sleep-sync",
      frequency: NSNumber(value: 24 * 60 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "counter/people_contacts",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "readContacts" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.readPeopleContacts(result: result)
    }
  }

  private func readPeopleContacts(result: @escaping FlutterResult) {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      result(FlutterError(
        code: "permission_denied",
        message: "Contacts permission is required",
        details: nil
      ))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let store = CNContactStore()
      let keys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
      ]
      let request = CNContactFetchRequest(keysToFetch: keys)
      request.sortOrder = .userDefault
      var rows: [[String: Any?]] = []

      do {
        try store.enumerateContacts(with: request) { contact, _ in
          let fullName = [contact.givenName, contact.familyName]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
          let displayName = fullName.isEmpty ? contact.organizationName : fullName
          let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
          let email = contact.emailAddresses.first?.value as String? ?? ""
          let birthday = contact.birthday
          let avatar = contact.thumbnailImageData.map {
            "data:image/jpeg;base64," + $0.base64EncodedString()
          } ?? ""
          rows.append([
            "external_id": contact.identifier,
            "display_name": displayName,
            "primary_phone": phone,
            "primary_email": email,
            "birthday_month": birthday?.month,
            "birthday_day": birthday?.day,
            "birthday_year": birthday?.year,
            "avatar_data_uri": avatar,
            "raw_meta": ["platform": "ios"],
          ])
        }
        DispatchQueue.main.async { result(rows) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "contacts_read_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }
}
