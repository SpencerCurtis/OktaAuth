# OktaAuth

## Introduction 

This library is meant to be used primarily by Lambda School students. 

`OktaAuth` provides a simple way of using Okta's PKCE authentication flow. It is meant to take the burden of working through the flow yourself and instead you need to provide a few pieces of information to `OktaAuth`, call a few functions and you're up and running.

A sample project with this package integrated can be found [here](https://github.com/Lambda-School-Labs/labs-ios-starter).

Note: While unnecessary for using this package, if you are interested in learning about this flow and how OktaAuth works behind the scenes, refer to the five or so pages inside of the ["Implement the Authorization Code Flow with PKCE"](https://developer.okta.com/docs/guides/implement-auth-code-pkce/overview/) section.


## Installation

If you are using the sample project, you can skip the installation as it should already have `OktaAuth` added.

- Add `OktaAuth` to your project using Swift Package Manager. 
	- If using an Xcode project, go to File -> Swift Packages -> Add Package Dependency... then paste in this repository's URL (https://github.com/SpencerCurtis/OktaAuth) and click "Next". 
	- On the "Choose Package Options" window that will appear, the rules you apply to have the Swift Package Manager update the package are up to you. Once you decide the rules you want click "Next".
	- On the next window, everything should be fine the way it is. The `OktaAuth` library should be added to your application target. When you have ensured that is the case, click "Finish".

At this point, you should be able to import `OktaAuth` wherever needed. As a side-note, If you ever need to update this or any other Swift Package, go to File -> Swift Packages -> Update to Latest Package Versions.

### Initialization
 
 You should only have a single instance of the `OktaAuth` class. The class instance will hold on to the credentials once the user has gone through the authentication flow. Because of this, if you have multiple instances of the `OktaAuth` class the credentials will not exist in every instance. 
 
In the sample project the class was initialized in the `ProfileController`. The model controller used a shared instance to be available throughout the application. While the singleton pattern is often looked down on, it fit the situation in this case. If you choose to follow this same setup, of course be sure not to abuse it. Consider still making a variable in each class/struct you would access the singleton such as this to still allow for dependency injection:

```swift
class SomeViewController: UIViewController {

var profileController = ProfileController.shared

...
```

Feel free to use an alternate way of maintaining a single instance of this class if you like.

- The class requires three arguments:
	- `baseURL`: This should be the base URL to your Okta authentication server. This likely shouldn't have any paths added on to it. For example: `https://yourAuthServer.okta.com`
	- `clientID`: Matches the Client ID of your Okta OAuth application that you created. You can find it at the bottom of your application's General tab in Okta. It should look something like this: `0obdfa90iqbWwsV0R4x6`
	- `redirectURI`: This is the URL with a custom scheme that you set up when you created your Okta application. You can view your redirect URI(s) and add more in the application's General Settings under __Login redirect URIs__. See [this screenshot](https://tk-assets.lambdaschool.com/276caf96-fcd4-4ccc-80af-bb3ec46f9f0f_ScreenShot2020-07-16at4.38.27PM.png). Note that this __must__ be set up on Okta's side with a unique URL scheme. Your team's manager of Okta can add more redirect URIs after the application is created.

```swift
let oktaAuth = OktaAuth(baseURL: URL(string: "https://yourAuthServer.okta.com/")!,
                            clientID: "0obdfa90iqbWwsV0R4x6",
                            redirectURI: "labs://scaffolding/implicit/callback")
```


 
 ### User Authentication
 
 In order to sign the user in using Okta, we will open Safari at the correct URL for them. In the sample project this is done in the `LoginViewController`.
 
 Whenever you choose, such as an IBAction, use `UIApplication`'s `open(URL)` method with the result of `OktaAuth's `identityAuthURL()` method as the argument. This will open Safari at the correct URL for the user to put in their Okta username and password. As an example the sample project's action looks like this:
 
 ```swift
 @IBAction func signIn(_ sender: Any) {
	UIApplication.shared.open(ProfileController.shared.oktaAuth.identityAuthURL()!)
}
```
 
 
 ### iOS App Redirection
 
 The `redirectURI` you passed into the `OktaAuth` initializer is what tells Okta to open back up your application once the user has finished signing in successfully.
 
 Your Xcode project must configure a custom URL scheme that matches the one that is set up in your apps Okta server. If you are a Lambda School student, reach out to Ryan Hamblin if you need help figuring out what the custom scheme is for your Labs project.
 
 - To set this up:
	 -  Navigate to the blue project file at the top of the file navigator
	 -  Click on the "Info" tab at the top of the screen that appears. 
	 -  Click the disclosure triangle on the "URL Types" section and click the plus (`+`) button that appears. This will add a new URL Type to fill out.
	 -  Add the identifier with _your specific project's bundle identifier_. If you are using the sample project, make sure the bundle identifier is something unique for your Labs project in the general tab. For example: `com.LambdaSchool.Ecosoap25`, etc. Once you have made sure it isn't `com.LambdaSchool.LabsScaffolding` then you can put the same unique bundle identifier in this "Identifier" field.
	 -  In the "URL Schemes" field, add the custom URL scheme. This would be what was set up on the Okta application. In the example project it is `labs://` instead of `https://`. You should not add the `://` after the scheme name, but just the text itself.

Here is an example of what the URL Type should look like when finished:

![](https://tk-assets.lambdaschool.com/7ead9b49-afb0-45f5-ac74-03a4ab2ad05b_ScreenShot2020-09-17at10.41.35AM.png)
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
