# docker-authentik <!-- omit from toc -->
Docker container for use as Identity Provider and authentication portal in front of a Traefik reverse-proxy.

## Table of Contents: <!-- omit from toc -->
- [1. Docker Setup](#1-docker-setup)
- [1.1 Troubleshooting](#11-troubleshooting)
- [1.1.1 Lost MFA token](#111-lost-mfa-token)
- [2. Authentik Setup](#2-authentik-setup)
  - [2.1. Set up your first user](#21-set-up-your-first-user)
  - [2.2. Configuring Authentik Embedded Outpost](#22-configuring-authentik-embedded-outpost)
  - [2.3. Configuring Traefik](#23-configuring-traefik)
- [3. Autentik configuration](#3-autentik-configuration)
  - [3.1. Check if email config is correct](#31-check-if-email-config-is-correct)
  - [3.2. Showing both username and password prompt at once on login screen](#32-showing-both-username-and-password-prompt-at-once-on-login-screen)
  - [3.3. Password complexity policy](#33-password-complexity-policy)
  - [3.4. MFA forced on login](#34-mfa-forced-on-login)
  - [3.5. Password recovery](#35-password-recovery)
  - [3.6. Invitation](#36-invitation)
- [4. Applications setup](#4-applications-setup)
  - [4.1. API calls bypassing authentication](#41-api-calls-bypassing-authentication)
  - [4.2. Servarr](#42-servarr)
    - [4.2.1. Traefik changes](#421-traefik-changes)
    - [4.2.2. Authentik settings](#422-authentik-settings)
  - [4.3. Nextcloud](#43-nextcloud)
    - [4.3.1. Authentik settings](#431-authentik-settings)
    - [4.3.2. Nextcloud settings](#432-nextcloud-settings)
  - [4.4. Synology NAS](#44-synology-nas)
    - [4.4.1. Authentik settings](#441-authentik-settings)
    - [4.4.2. Synology DSM settings](#442-synology-dsm-settings)
  - [4.5. Immich settings](#45-immich)
    - [4.5.1. Authentik settings](#451-authentik-settings)
    - [4.5.2. Immich settings](#452-immich-settings)
  - [4.6 Inventree settings](#46-inventree)
    - [4.6.1 Authentik settings](#461-authentik-settings)
    - [4.6.2 Inventree settings](#462-inventree-settings)
  - [4.7 Home-Assistant](#47-home-assistant)
    - [4.7.1 Authentik settings](#471-authentik-settings)
    - [4.7.2 Home-Assistant settings](#472-home-assistant-settings)
  - [4.8 Jellyfin settings](#47-jellyfin)
    - [4.8.1 Authentik settings](#481-authentik-settings)
    - [4.8.2 Jellyfin settings](#482-jellyfin-settings)

## 1. Docker Setup
1. Initialize config by running init.sh: `./init.sh`
1. Input personal information into `.env`
1. Generate postgresql password and authentik secret key, by using e.g. `openssl rand 56 | base64`, and input into `.env`
1. Make sure that Docker network `traefik` exists, `docker network ls`
1. Run `docker compose up` and check logs

### 1.1 Troubleshooting
#### 1.1.1 Lost MFA token
1. Find the TOTP table name: `docker exec authentik-db psql -U authentik -c "\dt *totp*"` (probably named `authentik_stages_authenticator_totp_totpdevice`)
1. Delete TOTP device for USER: `docker exec authentik-db psql -U authentik -c "DELETE FROM authentik_stages_authenticator_totp_totpdevice WHERE user_id = (SELECT id FROM authentik_core_user WHERE username = '<USER>');"`
1. Log in with the USER account and you should be promted to connect a new MFA device


## 2. Authentik Setup
Updated for version 2025.6.3
### 2.1. Set up your first user
1. Open browser and go to `auth.YOURDOMAIN.COM` and verify that you reach the Authentik login screen
1. Add `/if/flow/initial-setup/` at the end of the URL to reach the dialogue for setting up the initial admin account
1. Input the email and password you want to use for the default `akadmin` account and press `Continue`
1. Log into the default admin account using either usename `akadmin` or the email you entered in the previous step
1. Click the `Admin interface` button on the top-right
1. Go to `Directory->Users` in the menu on the left side and click `Create`
1. Input `Username` and `Name`, select `User type: Internal`, input `Email`, finally click Create
1. Click on your recently created user and go to the `Groups` tab and click `Add to existing group`
1. Click on the plus sign, select `authentik Admins` and press `Add`, then press `Add` again
1. Go back to the `Overview` tab and click `Set password` under the `Recovery` section
1. Log out of the current session and log in with your new user account instead
1. Go back to `Directory->Users` and click on the `akadmin` user
1. In the `User Info` pane scroll down to the `Actions` section and press the `Deactivate` button, then press `Update` in the popup prompt

You have now logged in for the first time, created your own user account and disabled the default admin account.

### 2.2. Configuring Authentik Embedded Outpost
1. In the `Admin interface`, go to `Applications->Outposts`, locate the `authentik Embedded Outpost` and verify that is says `Loggin in via https://auth.YOURDOMAIN.COM` in green below the name
1. Go to `Applications->Providers` and click `Create`
1. Select `Proxy Provider` and click `Next`
1. Input a `Name`, e.g. `Traefik Provider` and select `Authorization flow` with either implicit or explicit consent (determines if you are presented with an explicit prompt when being forwarded after logging in or not, prefer implicit)
1. Click `Forward auth (domain level)`, check that `Authentication URL` is `https://auth.YOURDOMAIN.COM` and set `Cookie domain` simply as `YOURDOMAIN.COM`
1. Change `Token validity` to your taste and click `Finish`
1. Go to `Applications->Applications` and click `Create`
1. Input `Name` and `Slug`, e.g. `Traefik`//`traefik`
1. Click the `Provider` field and select `Traefik Provider` (or whatever you named it in the previous step) and finally click `Create`
1. Go back to `Applications->Providers` and verify that `Traefik Provider` has a green checkmark and the text `Assigned to application Traefik` under the `Application` column
1. Go back to `Applications->Outposts` and click the  `Edit` button for the `authentik Embedded Outpost` (under the `Actions` column)
1. In the `Applications` section click on `Traefik` and press the > button to add it to `Selected Applications`, then press `Update`

You have now set up Authentik to be ready to be used with Traefik reverse-proxy with domain level forward auth.

### 2.3. Configuring Traefik
1. Go to your Traefik dir and open `dynamic_config.yml`
1. Add an Authentik middleware:
    ```
    middlewares:
        authentik-auth:
            forwardAuth:
            # Match base url to authentik server container name
            address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
            trustForwardHeader: true
            authResponseHeaders:
                - X-authentik-username
                - X-authentik-groups
                - X-authentik-email
                - X-authentik-name
                - X-authentik-uid
                - X-authentik-jwt
                - X-authentik-meta-jwks
                - X-authentik-meta-outpost
                - X-authentik-meta-provider
                - X-authentik-meta-app
                - X-authentik-meta-version
    ```
1. Optionally create a middleware chain that includes default security headers:
    ```
    middlewares:
        authentik:
            chain:
                middlewares:
                - authentik-auth
                - default-security-headers
    ```

Now you can use Authentik together with Traefik by including the authentik middleware in container labels, e.g.: `traefik.http.routers.APP_NAME.middlewares=authentik@file`.

## 3. Autentik configuration
### 3.1. Check if email config is correct
To verify that the email settings in `.env` are correct run `docker compose exec worker ak test_email RECIPIENT_EMAIL` to send a test email to `RECIPIENT_EMAIL`.

### 3.2. Showing both username and password prompt at once on login screen
Certain password managers will have an easier time auto-typing your login info if the username and password fields are both presented at once.

1. Go to `Flows and Stages->Stages` and click `Edit` for the `default-authentication-identification` stage
1. Under `Password stage` select `default-authentication-password`
1. (Optional) Enable `Enable "Remember me on this device"`
1. Click `Update`
1. Go to `Flows and Stages->Flows` and click the `default-authentication-flow` stage
1. Go to the `Stage Bindings` tab and delete the `default-authentication-password` stage

### 3.3. Password complexity policy
It's a good idea to enforce some kind of password policy.

1. Go to `Customisation->Policies` and click `Create`
1. Select `Password Policy`and click `Next`
1. Set a suitable `Name`, e.g. `password-complexity`
1. Expand the `Static rules` section
1. Input your choice of rules and enter an `Error message` that reflects the requirements, e.g. `Please enter a minimum of 12 characters with at least 1 uppercase, 1 lowercase, 1 digit and 1 symbol character.`
1. Click `Finish`
1. Go to `Flows and Stages->Stages`, click `Edit` for the `default-source-enrollment-prompt` stage
1. Scroll down to `Validation Policies`, select the password policy created previously under `Available Policies` and click `>` to add it to `Selected Policies.
1. Make sure to remove any other default policies and click `Update`
1. Repeat above for the `default-password-change-prompt` stage while also removing the `default-password-change-password-policy` if present

### 3.4. MFA forced on login
It's a good idea to enforce MFA for something that provides such powerful means of access. Here's how to force setup of MFA using TOTP using e.g. Google Authenticator app.

1. Go to `Flows and Stages->Stages`, click `Edit` for `default-authentication-mfa-validation`
1. Under `Stage-specific settings->Device classes` select the MFA types you want to allow, in this case only `TOTP Authenticators` for Google Authenticator app
1. Set `Not configured action` to `Force the user to configure an authenticator`
1. Under `Configuration stages` select only `default-authenticator-totp-setup`, click `Update`
1. Go to `Flows and Stages->Flows` and click on `default-source-enrollment`
1. Go to the `Stage Bindings` tab, click `Bind existing stage` and input:
    - Stage: `default-authentication-mfa-validation`
    - Order: 2
1. Update the order of the `default-source-enrollment-login` stage to 3, the resulting list should be:
    | Order | Name |
    | ----: | :--- |
    | 0 | default-source-enrollment-prompt |
    | 1 | default-source-enrollment-write |
    | 2 | default-authentication-mfa-validation |
    | 3 | default-source-enrollment-login |

### 3.5. Password recovery
If users forget their password it's nice if they're able to reset their passwords on their own.

1. Go to `Flows and Stages->Stages` and click `Create`
1. Select `Identification Stage` and click `Next`
1. Set a suitable name, e.g. `recovery-authentication-identification`, under `User fields` select `Username` and `Email` and click `Finish`
1. Click `Create` again and select `Email Stage`, click `Next`
1. Set a suitable `Name`, e.g. `recovery-email`
1. Set `Subject` to e.g. `Authentik password recovery`, click `Finish`
1. Go to `Flows and Stages->Flows` and click `Create`
1. Set `Name`/`Title`/`Slug` as `Recovery`/`Recovery`/`recovery`
1. Set `Designation` as `Recovery`
1. Click `Create`
1. Click on the `recovery` flow we just created and go to the `Stage Bindings` tab
1. Add bindings by clicking `Bind existing stage` and setting up according to the table below:
    | Order | Stage | Type |
    | ----: | :---- | :--- |
    | 10 | recovery-authentication-identification | Identification Stage |
    | 20 | recovery-email | Email Stage |
    | 30 | default-password-change-prompt | Prompt Stage |
    | 40 | default-password-change-write | User Write Stage |
1. Go to `Flows and Stages->Stages` and click `Edit` for the `default-authentication-identification` stage
1. Under `Flow settings->Recovery flow` select `recovery (Recovery)` and click `Update`

To be able to manually generate a recovery link for a user also:
1. Go to `System->Brands` and click `Edit` for the relevant brand (probably `authentik-default`)
1. Expand the `Default flows` section and set `Recovery flow` to `recovery (Recovery)`
1. Click `Update`


### 3.6. Invitation
It's a bad idea to allow anyone visiting the login page to register for an account. Invitation link with a set expiration time is a better solution.

1. Go to `Directory->Groups` and click `Create`
1. Set a suitable name, e.g. `authentik Users`
1. Make sure `Is superuser` is switched **OFF**, click `Create`
1. Click on your recently created group, go to the `Users` tab and click on `Add existing user`
1. Click on the plus sign, select your currently existing normal user accounts, press `Add` and then press `Add` again
1. Go to `Flows and Stages->Stages` and click `Create`
1. Select `User Write Stage` and click `Next`
1. Set a suitable name, e.g. `enrollment-invitation-write`
1.  Under `Stage-specific settings` make sure `Create users when required` is selected and uncheck `Create users as inactive`
1. Under `User type` make sure `Internal` is selected
1. Under `Group` select the recently created `authentik Users` group
1. Click `Finish`
1. Click `Create` again and select `Invitation Stage`, click `Next`
1. Set a suitable name, e.g. `enrollment-invitation`
1. Make sure `Continue flow without invitation` is **OFF** and click `Finish`
1. Click `Create` again and select `Email Stage`
1. Set `Name` to `enrollment-invitation-email`, `Subject` to `Account Confirmation` and `Template` to `Account Confirmation`, finally click `Finish`
1. Go to `Flows and Stages->Flows` and click `Create`
1. Set `Name` and `Title`to `Enrollment Invitation`
1. Set `Designation` to `Enrollment`
1. Under `Behavior settings` check `Compatibility mode` and click `Create`
1. Click the recently created `enrollment-invitation` flow and go to the `Stage Bindings` tab
1. Add bindings by clicking `Bind existing stage ` and setting up according to the table below:

    | Order | Stage | Type |
    | ----: | :---- | :--- |
    | 10 | enrollment-invitation | Invitation Stage |
    | 20 | default-source-enrollment-prompt | Prompt Stage |
    | 30 | enrollment-invitation-write | User Write Stage |
    | 40 | enrollment-invitation-email | Email Stage |
    | 50 | default-source-enrollment-login | User Login Stage |

1. Click on `Edit Stage` for the `default-source-enrollment-prompt` stage
1. Under `Stage-specific settings->Fields` select the following entries:
    * default-user-settings-field-username
    * default-user-settings-field-name
    * default-user-settings-field-email
    * initial-setup-field-password
    * initial-setup-field-password-repeat
1. Check under `Validation Policies` that `password-complexity` is selected, click `Update`

You can now go to `Directory->Invitations` and click `Create` to create an invitation link. Set a suitable name and expiration time. Make sure to select the `enrollment-invitation` flow and make sure `Single use` is checked.
1. Expand the recently created invite and `Link to use the invitation` will contain the link to be distributed.

## 4. Applications setup
### 4.1. API calls bypassing authentication
If you want to allow API calls to a certain application to bypass authentication simply add `^\/api\/.*` to `Advanced protocol settings->Unauthenticated Paths` under the relevant Provider.

### 4.2. Servarr
Authentik can be set up to contain the user//pass for the HTTP logins for the various Servarr apps and to forward credentials to the respective app after authentication via Authentik. This way you can keep authentication activated for each app but still only have to log in once when going through Authentik.

#### 4.2.1. Traefik changes
1. Go to your Traefik dir and open your `dynamic_config.yml`
1. Create a middleware similar to the one in the general Traefik setup above but including the `authorization` header (this is required for Authentik to be able to forward the credentials):
    ```
    middlewares:
        authentik-auth-http:
            forwardAuth:
                # Match base url to authentik server container name
                address: http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
                trustForwardHeader: true
                authResponseHeaders:
                    - X-authentik-username
                    - X-authentik-groups
                    - X-authentik-email
                    - X-authentik-name
                    - X-authentik-uid
                    - X-authentik-jwt
                    - X-authentik-meta-jwks
                    - X-authentik-meta-outpost
                    - X-authentik-meta-provider
                    - X-authentik-meta-app
                    - X-authentik-meta-version
                    - authorization
    ```
1. Optionally create a middleware chain similar to above:
    ```
    middlewares:
        authentik-http:
            chain:
                middlewares:
                    - authentik-auth-http
                    - default-security-headers
    ```

For the services where you want to use the HTTP-Basic authentication forwarding via Authentik you need to replace the default authentik middleware chain with the `authentik-http` created above instead.

#### 4.2.2. Authentik settings
1. Open the Authentik Admin Interface
1. Go to `Directory->Groups` and click `Create`
1. Set a suitable name, e.g. `Servarr Users`
1. Under `Attributes` input a list of usernames//passwords for the different Servarr apps, e.g.:
    - prowlarr_user: PROWLARR_USERNAME
    - prowlarr_password: PROWLARR_PASSWORD
    - sonarr_user: SONARR_USERNAME
    - sonarr_password: SONARR_PASSWORD
    - etc...
1. Click `Create`
1. Click on the recently created group, go to the `Users` tab and click `Add existing user`
1. Click the plus sign, select the users you want to be able to access the Servarr apps, click `Add` and then `Add` again
1. Go to `Applications->Providers` and click `Create`
1.  Select `Proxy Provider` and click `Next`
1. Set a suitable name, e.g. `Prowlarr Provider` and select `implicit-concent` under `Authorization flow`
1. Click `Forward auth (single application)`
1. Set `External host` to the externally accessible address for the app, e.g. `https://prowlarr.DOMAIN.COM`
1. Expand `Authntication settings` and make sure that both `Intercept header authentication` and `Send HTTP-Basic Authentication` are **ON**
1. Set `HTTP-Basic Username Key` and `HTTP-Basic Password Key` to `prowlarr_user` and `prowlarr_password` respectively (matching the keys in the list set up above)
1. Click `Finish`
1. *Repeat Provider creation for each individual app in your stack*
1. Go to `Applications->Applications` and click `Create`
1. Set a suitable name, e.g. `Prowlarr` and the slug similarly to `prowlarr`
1. Under `Provider` select the `Prowlarr Provider` created previously and click `Create`
1. *Repeat Application creation for each individual app in your stack*
1. Go to `Applications->Outposts` and open `authentik Embedded Outpost` for editing
1. Under `Applications` select each application created previously and click > to add them to `Selected Applications
1. Click `Update`
1. The previously created providers should now be listed in the `Providers` tab for `authentik Embedded Outpost`

### 4.3. Nextcloud
Authentik has a community integration for Nextcloud to allow user login and provisioning via Authentik.

#### 4.3.1. Authentik settings
Make sure usernames are immutable by going to `System->Settings` in the `Admin Interface` and checking that `Allow users to change username` is **OFF**.

1. Open the Authentik Admin Interface
1. Go to `Directory->Groups` and click `Create`
1. Create a group called `nextcloud Admins`, this will control which users are given admin permissions in `Nextcloud`
1. Create a group called `nextcloud Users`, this will control which users are allowed to access `Nextcloud` (to prevent Nextcloud accounts from being provisioned for users who aren't supposed to have access)
1. Go to `Customization->Property Mappings` and click `Create`
1. Select `Scope Mapping` and click `Next`
1. Set `Name` to `Nextcloud Profile` and `Scope name` to `profile`
1. In `Expression` enter the following:
   ```
    # Extract all groups the user is a member of
    groups = [group.name for group in user.groups.all()]

    # Nextcloud admins must be members of a group called "admin".
    # This is static and cannot be changed.
    # We append a fictional "admin" group to the user's groups if they are a member of "nextcloud Admins" in authentik.
    # This group would only be visible in Nextcloud and does not exist in authentik.
    if "nextcloud Admins" in groups:
        groups = ["admin"]
    else:
        groups = []

    return {
        # Display name
        "name": request.user.name,
        "groups": groups,
        # To set a quota set the "nextcloud_quota" property in the user's attributes
        "quota": user.group_attributes().get("nextcloud_quota", None),
        # To connect an already existing user, set the "nextcloud_user_id" property in the
        # user's attributes to the username of the corresponding user on Nextcloud.
        # Uses the Authentik username if attribute is not set.
        "user_id": user.attributes.get("nextcloud_user_id", str(user.username)),
    }
    ```
1. Click `Finish`
1. Go to `Applications->Providers` and click `Create`
1. Select `OAuth2/OpenID Provider` and click `Next`
1. Enter the following:
    - Name: `Nextcloud Provider`
    - Authorization flow: `implicit-consent`
    - Client type: `Confidential`
    - Redirect URIs/Origins (RegEx): `https://nc.DOMAIN.COM/apps/user_oidc/code` (make sure you're using the correct path prefix)
1. Under `Advanced protocol settings->Scopes` select:
    - `authentik default OAuth Mapping: OpenID 'email'`
    - `authentik default OAuth Mapping: OpenID 'openid'`
    - `authentik default OAuth Mapping: OpenID 'profile'`
    - `Nextcloud Profile`
1. Make sure that `Advanced protocol settings->Subject mode: Based on the User's username` is selected
1. Make sure that `Include claims in id_token` at the bottom is **ON**
1. Take note of your `Client ID` and `Client Secret`, you will use this in the Nextcloud stage
1. Go to `Applications->Applications` and click `Create`
1. Enter the following:
    - Name: `Nextcloud`
    - Slug: `nextcloud`
    - Provider: `Nextcloud Provider`
1. Click `Create`
1. Click on the recently created application and go to the `Policy / Group/ User Bindings` tab
1. Click `Bind existing Policy / Group / User`, select the `Group` option and then select the `nextcloud Users` group

To map an Authentik user to an existing Nextcloud account give the user an attribute like `nextcloud_user_id: NEXTCLOUD_ACCOUNT_NAME`. To give a user a quota limit give it an atrtibute like `nextcloud_quota: 10 GB`.

#### 4.3.2. Nextcloud settings
1. Log into the web UI using an admin account, click on the profile icon in the top-right and then click on `Apps`
1. Select the `Integration` category to the left and look for `OpenID Connect user backend`, enable it
1. Go to the top-right menu again and this time click `Administration Settings`
1. In the left-side menu list click on `OpenID Connect`
1. Click the plus sign under `Registered Providers` and enter the following:
   - Identifier: `Authentik`
   - Client ID: See the [Authentik section](#421-authentik-settings)
   - Client secret: See the [Authentik section](#421-authentik-settings)
   - Discovery endpoint: `https://auth.DOMAIN.COM/application/o/nextcloud/.well-known/openid-configuration`
   - Scope: `openid email profile`
   - User ID mapping: `user_id`
   - Quota mapping: `quota`
   - Groups mapping: `groups` (Requires `Use group provisioning` to be checked further down)
   - Display name mapping: `name` (Under `Extra attributes mapping`)
   - Email mapping: `email` (Under `Extra attributes mapping`)
   - Use unique user id: Turn this **OFF**

To make Authentik the default login method for Nextcloud go to your Nextcloud docker directory and run `docker compose exec -u www-data nextcloud php occ config:app:set --value=0 user_oidc allow_multiple_user_backends`.

### 4.4. Synology NAS
Authentik has a community integration for Synology DSM to allow user login via Authentik.

#### 4.4.1. Authentik settings
1. Open the Authentik Admin Interface
1. Go to `Applications->Providers` and click `Create`
1. Select `OAuth2/OpenID Provider` and click `Next`
1. Enter the following:
   - Name: Synology Provider
   - Authorization flow: implicit-consent
   - Client type: `Confidential`
   - Redirect URIs/Origins (RegEx): `https://nas.DOMAIN.COM/#/signin` (use whatever subdomain you set up in your Traefik dynamic_config.yml)
   - Subject mode: `Based on the User's username`
1. Click `Finish`
1. Go to `Applications->Applications` and click `Create`
1. Enter `Name`//`Slug` as `NAS`//`nas` and select the recently created provider, click `Create`

#### 4.4.2. Synology DSM settings
1. Log in to DSM with an admin account
1. Go to `Control Panel->Domain/LDAP` and click on the `SSO Client` tab
1. Check the `Enable OpenID Connect SSO service` box and click the `OpenID Connect SSO Settings` button below it
1. Enter the following:
   - Name: `Authentik`
   - Wellknown URL: `https://auth.DOMAIN.COM/application/o/nas/.well-known/openid-configuration`
   - Application ID: Client ID from the Synology Provider
   - Application Key: Client Secret from the Synology Provider
   - Redirect URL: `https://nas.DOMAIN.COM/#/signin`
   - Authorization scope: `openid profile email`
   - Username claim: `preferred_username`

Currently doesn't work properly with DSM <7.2 so TBC...

### 4.5 Immich
Authentik has a community integration for Immich to allow user login and provisioning via Authentik.

#### 4.5.1 Authentik settings
1. Open the Authentik Admin Interface
1. Go to `Applications->Providers` and click `Create`
1. Select `OAuth2/OpenID Provider` and click `Next`
1. Enter the following:
    - Name: `Immich Provider`
    - Authorization flow: `implicit-consent`
    - Client type: `Confidential`
    - Redirect URIs/Origins (RegEx):
        - `https://immich.DOMAIN.COM/auth/login`
        - `https://immich.DOMAIN.COM/user-settings`
        - `app.immich://oauth-callback`
1. Take note of the `Client ID` and `Client Secret`, we will need these in the Immich setup
1. Click `Finish`
1. Go to `Applications->Applications` and click `Create`
1. Enter the following:
    - Name: `Immich`
    - Slug: `immich`
    - Provider: `Immich Provider`
1. Click `Create`

#### 4.5.2 Immich settings
1. Log in with the admin account initially set up for Immich
1. Click the top-right circle icon and select `Administration`
1. From the left-side menu select `Settings` and then `Authentication Settings->OAuth`
1. Enable `Login with OAuth` and fill out:
    - ISSUER_URL: `https://auth.DOMAIN.COM/application/o/immich/`
    - CLIENT_ID: Use value from Authentik Provider setup
    - CLIENT_SECRET: Use value from Authentik Provider setup
    - AUTO LAUNCH: Set to ON
1. Click `Save` at the bottom of the form

### 4.6 Inventree
Authentik doesn't have an outright integration for Inventree but Inventree supports general OIDC.

#### 4.6.1 Authentik settings
1. Go to `Customization->Propery Mappings` and click `Create`
1. Select `Scope Mapping` and click `Next`
1. Enter the following:
    - Name: `Inventree Profile Mapping`
    - Scope name: `profile`
    - Description: `Split Authentik displayname into separate First and Last Name entities for conformity with how Inventree handles user names`
    - Expression:
    ```
    name_parts = request.user.name.split(" ", 1)
    given = name_parts[0]
    family = name_parts[1] if len(name_parts) > 1 else ""

    return {
        "name": request.user.name,
        "given_name": given,
        "family_name": family,
        "preferred_username": request.user.username,
        "nickname": request.user.username,
        "groups": [group.name for group in request.user.ak_groups.all()],
    }
    ```
1. Click `Finish`
1. Go to `Applications->Providers` and click `Create`
1. Select `OAuth2/OpenID Provider` and click `Next`
1. Enter the following:
    - Name: `Inventree Provider`
    - Authorization flow:: `implicit-consent`
    - Client type: `Confidential`
    - Redirect URIs/Origins (RegEx): ("authentik" refers to the provider id set in Inventree)
        - `https://parts.DOMAIN.COM/accounts/authentik/login/callback/`
        - `https://inventree.DOMAIN.COM/accounts/authentik/login/callback/`
1. Take note of the `Client ID` and `Client Secret`, we will need these in the Inventree setup
1. Expand the `Advanced protocol settings` section and look at th e `Selected Scopes` list
1. Remove `authentik default OAuth Mapping: OpenID 'profile'` and add `Inventree Profile Mapping`
1. Click `Finish`
1. Go to `Applications->Applications` and click `Create`
1. Enter the following:
    - Name: `Inventree`
    - Slug: `inventree`
    - Provider: `Inventree Provider`
1. Click `Create`

#### 4.6.2 Inventree settings
1. Log in as superuser/admin and go to `Admin Center`
1. Under `Operations->Users / Access`, expand the `Groups` section and add groups called `Admins` and `Users`
1. Go to `System Settings->Authentication`
1. Make sure that the following options are **ON**:
    - Enable SSO
    - Enable SSO registration
    - Auto-fill SSO users
    - Enable SSO group sync
    - Remove groups outside of SSO
1. Make sure that the following option is **OFF**:
    - Enable registration
1. Set `SSO group map` to `{"inventree Admins": "Admins"}`
1. Set `Group on signup` to `Users`
1. Go to the Django admin panel by entering `https://inventree.DOMAIN.COM/admin/`, scroll down to `SOCIAL ACCOUNTS` and click on `Social applications`
1. Click `ADD SOCIAL APPLICATION +` and enter:
    - Provider: `OpenID Connect`
    - Provider ID: `authentik`
    - Name: `Authentik`
    - Client id: As per the Authentik Provider
    - Secret key: As per the Authentik Provider
    - Settings: `{"server_url": "https://auth.DOMAIN.COM/application/o/inventree/"}`
1. Click `SAVE`

Note that you will need to promote users to staff/superuser status manually as at the time of writing there's no natively supported way to automate it.

### 4.7 Home-Assistant
#### 4.7.1 Authentik settings
1. Go to `Applications->Providers` and click `Create`
1. Select `OAuth2/OpenID Provider` and click `Next`
1. Enter the following:
    - Name: `HomeAssistant Provider`
    - Authorization flow:: `implicit-consent`
    - Client type: `Confidential`
    - Redirect URIs/Origins (RegEx): Strict,
        - `https://hass.DOMAIN.COM/auth/openid/callback`
1. Take note of the `Client ID` and `Client Secret`, we will need transfer these into HomeAssistant config
1. Click `Finish`
1. Go to `Applications->Applications` and click `Create`
1. Enter the following:
    - Name: `HomeAssistant`
    - Slug: `home-assistant`
    - Provider: `HomeAssistant Provider`
1. Click `Create`

#### 4.7.2 Home-Assistant settings
1. Log into HomeAssistant as the admin user via local ip
1. Install the `Terminal & SSH` addon by going to `Settings->Add-ons`, clicking on the `Add-on store` button at the bottom right, searching for `Terminal & SSH` and clicking `Install`
1. Click `Terminal` in the left-side menu and run `wget -O - https://get.hacs.xyz | bash -` to install `Home Assistant Community Store (HACS)`
1. Go to `Settings->Devices & services`, click `Add integration` at the bottom right, search for `HACS`, acknowledge the statements and click `SUBMIT`
1. Link HACS to your GitHub account (read-only access)
1. Open `HACS` in the left-side menu and search for the addon `Simple OpenID Connect (OIDC / SSO)` by user `cavefire`, install it
1. Open `/homeassistant/configuration.yaml`, e.g. by using the `Terminal & SSH` addon
1. Enter the following config at the bottom of the file:
```
homeassistant:
    external_url: https://hass.DOMAIN.COM
    internal_url: http://LOCAL_HASS_SERVER_IP:8123

http:
    use_x_forwarded_for: true
    trusted_proxies:
        - LOCAL_TRAEFIK_SERVER_IP

openid:
    client_id: FROM_AUTHENTIK
    client_secret: FROM_AUTHENTIK
    configure_url: "https://auth.DOMAIN.COM/application/o/home-assistant/.well-known/openid-configuration"
    username_filed: "preferred_username"
    scope: "openid profile email"
    block_login: true
    trusted_ips: #List of CIDR blocks that are not affected by block_login
        - "10.0.0.0/24" # e.g.
    openid_text: "Login with Authentik" # Text to display on the login page
    create_user: true # Automatically create users on first login
```

### 4.8 Jellyfin
We're not using Authentik middleware here but instead relying on LDAP for automating user setup and logging in via the regular Jellyfin login

#### 4.8.1 Authentik settings
First we need to setup a flow for allowing the service account access

1. Create a LDAP service password stage by going to `Flows and Stages->Stages->Create` and entering:
- Select type: `Password Stage`
- Name: `ldap-service-password`
- Backends: `User database + standard password` (only)
1. Click `Finish`

1. Create an Identificaton Stage by going to `Flows and Stages->Stages->Create` and entering:
- Select type: `Identification Stage`
- Name: `ldap-service-identification`
- User fields: `Username`
- Password stage: `ldap-service-password`
1. Click `Finish`

1. Create a User Login stage by goign to `Flows and Stages->Stages->Create` and entering:
- Select type: `User Login Stage`
- Name: `ldap-service-login`
1. Click `Finish`

1. Create an authentication flow specifically for LDAP service accounts by going to `Flows and Stages->Flows->Create` and entering:
- Name: `LDAP Service Account Bind`
- Title: `LDAP Service Account Bind`
- Slug: `ldap-service-account-bind`
- Designation: `Authentication`
- Authentication: `No requirement`
1. Click `Create`
1. Open the created flow and go to the `Stage Bindings` tab
1. Click `Bind existing Stage` and enter:
- Stage: `ldap-service-identification`
- Order: 10
1. Click `Create`
1. Click `Bind existing Stage` again and enter: 
- Stage: `ldap-service-login`
- Order: 30
1. Click `Create`

1. Create a LDAP service account for the LDAP plugin in Jellyfin to use to lookup users (read-only) by going to `Directory->Users->Create Service account` and entering:
- Username: `jellyfin-ldap`
- Create group: `Disable`
- Expiring: `Disable`
1. Click `Create` and take note of the generated `Password`, click `Close`

1. Create a role for LDAP search by going to `Directory->Roles->Create`, naming it `LDAP Search` and clicking `Create`
1. Go to `Applications->Providers` and click on the `Jellyfin LDAP` provider (not edit)
1. Go to the `Permissions` tab, click `Assign Object Permission` and enter:
- Role: `LDAP Search`
- Search full LDAP directory: Enabled
1. Click `Assign`
1. Go to `Directory->Users->jellyfin-ldap->Roles`
1. Click `Add to existing role`, select the `LDAP Search`role and click `Add`, then `Add` again

1. Create an LDAP provider by going to `Applications->Providers->Create->LDAP Provider` and entering:
- Name: `Jellyfin LDAP`
- Bind mode: `Direct binding`
- Search mode: `Direct querying`
- Code-based MFA Support: `Disabled`
- Bind flow: `ldap-service-account-bind` (has to be flow without MFA enforced!)
- Unbind flow: `default-invalidation-flow`
- Base DN: Leave as default (`DC=ldap,DC=goauthentik,DC=io)
1. Click `Finish`

1. Create a matching Application by going to `Applications->Applications->Create` and entering:
- Name: `Jellyfin`
- Slug: `jellyfin`
- Provider: `Jellyfin LDAP`
1. Click `Create`

1. Create an LDAP outpost by going to `Applications->Outposts->Create` and entering:
- Name: `Jellyfin LDAP Outpost`
- Type: `LDAP`
1. Move the `Jellyfin` application to `Selected Applications`
1. Click `Create`
1. Click the `View Deployment Info` on the newly create outpost and then on `Click to copy token` under `AUTHENTIK_TOKEN`
1. Click `Close`
1. Open your `.env` file and set `AUTHENTIK_LDAP_TOKEN` to the value you just copied from the outpost
1. Restart the LDAP container: `docker compose up -d --force-restart ldap`

#### 4.8.2 Jellyfin settings
1. Install the LDAP plugin by logging in as an admin account and going to `Dashboard->Catalog` and locating `LDAP Authentication` and clicking `Install`
1. Restart jellyfin: `docker compose up -d --force-recreate jellyfin`
1. Configure the plugin with the following:
- LDAP Server: `authentik-ldap`
- LDAP Port: `389`
- Bind User: `cn=ldapservice,ou=serviceaccounts,dc=ldap,dc=goauthentik,dc=io`
- Bind Password: The password for the `Service account` you created earlier
- Base DN: `dc=ldap,dc=goauthentik,dc=io`
- User filter: `(objectClass=user)`
- Username attribute: `cn`