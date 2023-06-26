# PDFEasy-iOS

PDF Easy is an iOS app for iPhone and iPad that allows to convert and manage pdf files. [App Store Link](https://apps.apple.com/us/app/pdf-easy-convert-edit/id1659625843).

# Main features

## Conversion and Import
1. Conversion of Word, Pages, PowerPoint, Keynote, Excel and Numbers files to pdf.
2. Image acquistion from gallery, camera and File app, and conversion to pdf.
3. Import pdf (from within the app and through app extension).
4. Scan documents to pdf.

## Edit
1. Add margins.
2. Change compression quality.
3. Add pages.
4. Reorder pages.
5. Delete pages.
6. Add text annotations.
7. Fill editable fields.
8. Add signature.
9. Remove/add password.

## Other
1. Share of pdf files.
2. Subscription to unlock share feature.
3. Stored created pdf through iCloud.
4. Deletion of created pdfs.
5. Onboarding with tutorial.
6. Tutorial to open pdf from outside the app through app extension.

# Setup

This project uses Firebase SDK for analytics and Facebook SDK for attribution of Facebook ads campaigns. Moreover, staging and production environments are separated to avoid analytics data pollution. Follow these instructions to add your own Firebase and Facebook information to the project.

1. Clone this project.
3. Add folders PdfExpert/Resources/Staging and PdfExpert/Resources/Production.
4. Inside each folder put your Firebase GoogleService-Info.plist file for the corresponding environment.
5. Inside each folder put a copy of the InfoTemplate.plist, renamed as Info.plist, for the corresponding environment. Within those files, update the values for the FacebookAppID and FacebookClientToken keys to match the ones on your Facebook App.
 
This app uses many features that require additional setup, such as subscriptions, iCloud and app extension. Maybe specific instructions will be added in the future, but for now they are left to the reader.

# Technologies

1. SwiftUI
2. StoreKit 2
3. Core Data
4. iCloud
5. PDFKit
6. Firebase Analytics
7. Firebase Remote Config (used to switch between two type of subscription screens)
8. VisionKit (used for the scanner feature)
9. PencilKit (used to take the user's signature)
