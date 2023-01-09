# Telenor ID authentication SDK

This is an updated version of the [Connect iOS SDK](https://github.com/telenordigital/connect-ios-sdk). This version includes
improvements in terms of network stability, security and has a straightfoward and clean API.

### Major features and changes
#### Chained API requests

It is common to have muliple requests to be executed at the same time, however when it comes to OAuth it is a known problem
when multiple requests can be using shared tokens. The outcome, typically, would be that some of the requests will not be
able to finish successfully, due to the fact that used tokes had already being consumed by another request.

To prevent this from happening SDK reassures that a new request inside SDK can only run when previous one had finished.

Due to the fact that SDK currently is supposed to support old version of iOS, the Semaphore is used to ensure the order of
the requests. In case if the minimum target version will be bumped up, SDK may start using async/await code in future.

#### Multipiple IDP support is removed

At this point it's unlikely that SDK will be used for other IDPs than Telenor ID, therefor the support of other IDPs was removed
from codebase.

#### HE support is removed

Header enrichment support always was problematic on iOS, since there is no way to influence the type of network (cellular/WiFi) that is used
by the SDK. With more changes in the security environment coming, it makes it more and more difficult to support the unsecure content loading
over the mobile network. Combined with the fact that the logic is untrivial to understand and was barely used in Nordic countries, it was
decided to remove the Header enrichment support.

#### .well-known configuration support is removed

.well-known configuration support was removed due to the fact that feature is unused and that changes that are typically causing the change
in configuration will also require users to update their application. That makes the need in remote configuration unnecessary.

#### Userinfo API was removed

At the process of the authentication Telenor ID backend provides the requested user information in a form of ID token. Please, use values from ID token to get necessary user information.

#### Cleaned up dependecies

SDK has a single [Alamofire](https://github.com/Alamofire/Alamofire) dependency, that should make future updates and maintenance easier.

#### Available through Swift Package Manager

SDK is only available over the Swift Package Manager and does not have support/was not tested with Cocoapods, Carthage or other package managers.


### Usage
#### Installation

You can install the SDK using the [Swift Package Manager](https://www.swift.org/package-manager/). You can use this repository as a reference.

#### Setup

Before starting to use SDK you will have to get your client credentials for Telenor ID. After that is in place, you can setup a `Configuration`
class inside the SDK. That setup typically doesn't change over the time in your application. Be sure you provide a correct `Environment`
to the configuration object.

```swift
let configuration = Configuration(
                      environment: Environment.staging,
                      clientId: "telenordigital-exampletelenorid-android",
                      redirectUrl: "telenordigital-exampletelenorid-android://oauth2callback",
                      callbackUrlScheme: "telenordigital-exampletelenorid-android"
                    )
```

After your configuration is set, you should provide it to the `TelenorIdSdk`, so that SDK can be aware which values it can use for
network requests.
```swift
TelenorIdSdk.useConfiguration(configuration)
```

After two steps above are done, it's now possible to use SDK to it's full power.

#### Network Service

Requests towards the Telenor ID backend are done via `NetworkService` class. `NetworkService` cannot be accessed or created directly
and has to be accessed via shared instance in `TelenorIdSdk.networkService()`.

`.authorize(...)`
: This method should be called to start the authentication process for the user. Method takes in a significant amount of parameters that will define the user journey. Please take a look at [API documentation](https://docs.telenordigital.com/apis/connect/id/authentication.html#authorization-server-user-authorization) to see the detailed description of the parameters.

`.refreshAccessToken(...)`
: This method should be called in case if the access token stored inside the SDK was consumed or is invalid due to various reasons. You can find more details at [API documentation](https://docs.telenordigital.com/apis/connect/id/authentication.html#authorization-server-token-post).

`.logout(...)`
: This method should be called when user is trying to log out of the service. Keep in mind, that this type of logging out the user doesn't clean the SSO cookie. A detailed description can be found at [API documentation](https://docs.telenordigital.com/apis/connect/id/authentication.html#authorization-server-user-logout-post).

`.revokeToken(...)`
: This method should revoke the provided token, making sure that user cannot login with in anymore. A detailed description can be found at [API documentation](https://docs.telenordigital.com/apis/connect/id/authentication.html#authorization-server-revoke-token-post).

#### Storage Service

`StorageService` is used to fetch some of the values that are stored inside SDK. There is typically no need for the SDK users to do that,
but in might be necessary to read the user information from ID Token for example.
 
#### Validator

Use `Validator.isAccessTokenValid(...)` to check if access token still can be used.
