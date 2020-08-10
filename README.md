# OktaAuth

## Introduction 

This library is meant to be used primarily by Lambda School students. 

`OktaAuth` provides a simple way of using Okta's PKCE authentication flow. It is meant to take the burden of working through the flow yourself and instead you need to provide a few pieces of information to `OktaAuth`, call a few functions and you're up and running.

## Installation

- Add `OktaAuth` to your project using Swift Package Manager. 
	- If using an Xcode project, go to File -> Swift Packages -> Add Package Dependency... then paste in this repository's URL (https://github.com/SpencerCurtis/OktaAuth) and click "Next". 
	- On the "Choose Package Options" window that will appear, the rules you apply to have the Swift Package Manager update the package are up to you. Once you decide the rules you want click "Next".
	- On the next window, everything should be fine the way it is. The `OktaAuth` library should be added to your application target. When you have ensured that is the case, click "Finish".

At this point, you should be able to import `OktaAuth` wherever needed. As a side-note, If you ever need to update this or any other Swift Package, go to File -> Swift Packages -> Update to Latest Package Versions.

## Setup

It is recommended that you have a single instance of the `OktaAuth` class in your application. You will need to use this class object in your project's `SceneDelegate` and anywhere you want use to the bearer token that will give you access to your project's backend. As such, the [labs-ios-starter](https://github.com/Lambda-School-Labs/labs-ios-starter) project put this instance in its model controller and the model controller itself uses a singleton instance. Feel free to use an alternate way of maintaining a single instance of this class. 

- The `OktaAuth` class' initializer will ask for three pieces of information:
	- The base URL to your Okta Application. For example, it might look like this: `https://auth.lambdalabs.dev/` or this: `https://labs-api-starter.herokuapp.com`.
	- The Client ID of your Okta Application. This can be found under the "Client Credentials" section of your application in Okta's website. It should look something like this: `0oacfa90iqbWwsV0R4x6`
	- Finally, the redirect URI. This will be used to open the iOS application back up once the user successfully finishes their authentication in Safari. More than one can be added to an Okta application on the website. To ensure there is no conflict with other applications on the user's device, it should have a unique scheme. For example it could be `myLabsProject://` in the place of the normal `https://`. You can view your redirect URI(s) and add more in the application's General Settings under __Login redirect URIs__. See [this screenshot](https://tk-assets.lambdaschool.com/276caf96-fcd4-4ccc-80af-bb3ec46f9f0f_ScreenShot2020-07-16at4.38.27PM.png).

Whoever is managing the Okta application for you should be able to make and/or get this information for you. 
