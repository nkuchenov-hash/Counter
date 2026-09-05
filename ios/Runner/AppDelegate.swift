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
      guard call.method == "requestAndReadContacts" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.requestAndReadPeopleContacts(result: result)
    }
  }

  private func requestAndReadPeopleContacts(result: @escaping FlutterResult) {
    let store = CNContactStore()
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .authorized:
      readAuthorizedPeopleContacts(store: store, result: result)
    case .notDetermined:
      store.requestAccess(for: .contacts) { [weak self] granted, error in
        guard granted else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "permission_denied",
              message: error?.localizedDescription ?? "Contacts permission is required",
              details: nil
            ))
          }
          return
        }
        self?.readAuthorizedPeopleContacts(store: store, result: result)
      }
    default:
      result(FlutterError(
        code: "permission_denied",
        message: "Contacts permission is required",
        details: nil
      ))
    }
  }

  private func readAuthorizedPeopleContacts(
    store: CNContactStore,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
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
      var rows: [[String: Any]] = []

      do {
        try store.enumerateContacts(with: request) { contact, _ in
          let fullName = [contact.givenName, contact.familyName]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
          let displayName = fullName.isEmpty ? contact.organizationName : fullName
          let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
          let email = contact.emailAddresses.first.map { String($0.value) } ?? ""
          let birthday = contact.birthday
          let avatar = contact.thumbnailImageData.map {
            "data:image/jpeg;base64," + $0.base64EncodedString()
          } ?? ""
          var row: [String: Any] = [
            "external_id": contact.identifier,
            "display_name": displayName,
            "primary_phone": phone,
            "primary_email": email,
            "avatar_data_uri": avatar,
            "raw_meta": ["platform": "ios"],
          ]
          if let month = birthday?.month, month > 0 { row["birthday_month"] = month }
          if let day = birthday?.day, day > 0 { row["birthday_day"] = day }
          if let year = birthday?.year, year > 0 { row["birthday_year"] = year }
          rows.append(row)
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
