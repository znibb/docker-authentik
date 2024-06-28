Docker container for use as Identity Provider and authentication portal in front of a Traefik reverse-proxy.

**Table of Contents:**
- [1. Docker Setup](#1-docker-setup)
- [2. Authentik Setup (Written for version 2024.4.2)](#2-authentik-setup-written-for-version-202442)
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
  - [API calls bypassing authentication](#api-calls-bypassing-authentication)
  - [4.1. Servarr](#41-servarr)
    - [4.1.1. Traefik changes](#411-traefik-changes)
    - [4.1.2. Authentik settings](#412-authentik-settings)
  - [4.2. Nextcloud](#42-nextcloud)
    - [4.2.1. Authentik settings](#421-authentik-settings)
    - [4.2.2. Nextcloud settings](#422-nextcloud-settings)
  - [4.3. Synology NAS](#43-synology-nas)
    - [4.3.1. Authentik settings](#431-authentik-settings)
    - [4.3.2. Synology DSM settings](#432-synology-dsm-settings)

## 1. Docker Setup
1. Initialize config by running init.sh: `./init.sh`
2. Input personal information into `.env`
3. Generate postgresql password and authentik secret key, by using e.g. `openssl rand 56 | base64`, and input into `./secrets/POSTGES_PASSWORD.secret` and `./secrets/AUTHENTIK_SECRET_KEY.secret` respectively
4. Make sure that Docker network `traefik` exists, `docker network ls`
5. Run `docker compose up` and check logs

## 2. Authentik Setup (Written for version 2024.4.2)
### 2.1. Set up your first user
1. Open browser and go to `auth.YOURDOMAIN.COM` and verify that you reach the Authentik login screen
2. Add `/if/flow/initial-setup/` at the end of the URL to reach the dialogue for setting up the initial admin account
3. Input the email and password you want to use for the default `akadmin` account and press `Continue`
4. Log into the default admin account using either usename `akadmin` or the email you entered in the previous step
5. Click the `Admin interface` button on the top-right
6. Go to `Directory->Users` in the menu on the left side and click `Create`
8. Input `Username` and `Name`, select `User type: Internal`, input `Email`, finally click Create
9. Click on your recently created user and go to the `Groups` tab and click `Add to existing group`
10. Click on the plus sign, select `authentik Admins` and press `Add`, then press `Add` again
11. Log out of the current session and log in with your new user account instead
12. Go back to `Directory->Users` and click on the `akadmin` user
13. In the `User Info` pane scroll down to the `Actions` section and press the `Deactivate` button, then press `Update` in the popup prompt

You have now logged in for the first time, created your own user account and disabled the default admin account.

### 2.2. Configuring Authentik Embedded Outpost
1. In the `Admin interface`, go to `Applications->Outposts`, locate the `authentik Embedded Outpost` and verify that is says `Loggin in via https://auth.YOURDOMAIN.COM` in green below the name
2. Go to `Applications->Providers` and click `Create`
3. Select `Proxy Provider` and click `Next`
4. Input a `Name`, e.g. `Traefik Provider` and select `Authorization flow` with either implicit or explicit consent (determines if you are presented with an explicit prompt when being forwarded after logging in or not)
5. Click `Forward auth (domain level)`, check that `Authentication URL` is `https://auth.YOURDOMAIN.COM` and set `Cookie domain` simply as `YOURDOMAIN.COM`
6. Change `Token validity` to your taste and click `Finish`
7. Go to `Applications->Applications` and click `Create`
9. Input `Name` and `Slug`, e.g. `Traefik`//`traefik`
10. Click the `Provider`field and select `Traefik Provider` (or whatever you named it in the previous step) and finally click `Create`
11. Go back to `Applications->Providers` and verify that `Traefik Provider` has a green checkmark and the text `Assigned to application Traefik` under the `Àpplication` column
12. Go back to `Applications->Outposts` and click the  `Edit` button for the `authentik Embedded Outpost` (under the `Actions` column)
13. In the `Applications` section click on `Traefik` and press the > button to add it to `Selected Applications`, then press `Update`

You have now set up Authentik to be ready to be used with Traefik reverse-proxy with domain level forward auth.

### 2.3. Configuring Traefik
1. Go to your Traefik dir and open `dynamic_config.yml`
2. Add an Authentik middleware:
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
3. Optionally create a middleware chain that includes default security headers:
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

1. Go to `Flows and Stages->Flows` and click `Edit Stage` for the `default-authentication-identification` stage
2. Under `Password stage` select `default-authentication-password` and click `Update`
3. Delete `default-authentication-password`

### 3.3. Password complexity policy
It's a good idea to enforce some kind of password policy.

1. Go to `Customisation->Policies` and click `Create`
2. Select `Password Policy`and click `Next`
3. Set a suitable `Name`, e.g. `password-complexity`
4. Expand the `Static rules` section
6. Input your choice of rules and enter an `Error message` that reflects the requirements, e.g. `Please enter a minimum of 12 characters with at least 1 uppercase, 1 lowercase, 1 digit and 1 symbol.`

### 3.4. MFA forced on login
It's a good idea to enforce MFA for something that provides such powerful means of access. Here's how to force setup of MFA using TOTP using e.g. Google Authenticator app.

1. Go to `Flows and Stages->Flows`, click on `default-authentication-flow` and go to the `Stage Bindings` tab
2. Click `Bind existing stage`, for `Stage` select `default-authentication-mfa-validation` stage and set `Order` to `30`
3. Click `Edit Stage` for `default-authentication-mfa-validation`
4. Under `Stage-specific settings->Device classes` select the MFA types you want to allow, in this case only `TOTP Authenticators` for Google Authenticator app
6. Set `Not configured action` to `Force the user to configure an authenticator`
7. Under `Configuration stages` select only `default-authenticator-totp-setup`, click `Update`

### 3.5. Password recovery
If users forget their password it's nice if they're able to reset their passwords on their own.

1. Go to `Flows and Stages->Stages` and click `Create`
2. Select `Identification Stage` and click `Next`
3. Set a suitable name, e.g. `recovery-authentication-identification`, select `User fields` `Username` and `Email` and click `Update`
4. Click `Create` again and select `Email Stage`, click `Next`
5. Set a suitable `Name`, e.g. `recovery-email`
6. Set `Subject` to `Password Recovery`
7. Go to `Flows and Stages->Flows` and click `Create`
8. Set `Name`/`Title`/`Slug` as `Recovery`/`Recovery`/`recovery`
10. Set `Designation` as `Recovery`
11. Click `Create`
12. Click on the `recovery` flow we just created and go to the `Stage Bindings` tab
13. Add bindings by clicking `Bind existing stage` and setting up according to the table below:

    | Order | Stage |
    | ----: | :---- |
    | 10 | recovery-authentication-identification |
    | 20 | recovery-email |
    | 30 | default-password-change-prompt |
    | 40 | default-password-change-write |

14. Click on `Edit Stage` for the `default-password-change-prompt` stage
15. Under `Validation Policies` select `password-complexity` and click `Update`
16. Click on `Edit Stage` for the `default-authentication-identification` stage
17. Under `Flow settings->Recovery flow` select `Recovery` and click `Update`

### 3.6. Invitation
It's a bad idea to allow anyone visiting the login page to register for an account. Invitation link with a set expiration time is a better solution.

1. Go to `Directory->Groups` and click `Create`
2. Set a suitable name, e.g. `authentik Users`
3. Make sure `Is superuser` is switched **OFF**, click `Create`
4. Click on your recently created group, go to the `Users` tab and click on `Add existing user`
5. Click on the plus sign, select your currently existing normal user accounts, press `Add` and then press `Add` again
6. Go to `Flows and Stages->Stages` and click `Create`
7. Select `User Write Stage` and click `Next`
8. Set a suitable name, e.g. `enrollment-invitation-write`
9.  Under `Stage-specific settings` make sure `Create users when required` is selected and uncheck `Create users as inactive`
10. Under `User type` make sure `Internal` is selected
11. Under `Group` select the recently created `authentik Users` group
12. Click `Finish`
13. Click `Create` again and select `Invitation Stage`, click `Next`
14. Set a suitable name, e.g. `enrollment-invitation`
15. Make sure `Continue flow without invitation` is **OFF** and click `Finish`
16. Click `Create` again and select `Email Stage`
17. Set `Name` to `enrollment-invitation-email`, `Subject` to `Account Confirmation` and `Template` to `Account Confirmation`, finally click `Finish`
18. Go to `Flows and Stages->Flows` and click `Create`
20. Set `Name` and `Title`to `Enrollment Invitation`
21. Set `Designation` to `Enrollment`
22. Under `Behavior settings` check `Compatibility mode` and click `Create`
23. Click the recently created `enrollment-invitation` flow and go to the `Stage Bindings` tab
24. Add bindings by clicking `Bind existing stage ` and setting up according to the table below:

    | Order | Stage |
    | ----: | :---- |
    | 10 | enrollment-invitation |
    | 20 | default-source-enrollment-prompt |
    | 30 | enrollment-invitation-write |
    | 40 | enrollment-invitaion-email |
    | 50 | default-source-enrollment-login |

25. Click on `Edit Stage` for the `default-source-enrollment-prompt` stage
26. Under `Stage-specific settings->Fields` select the following entries:
    * default-user-settings-field-username
    * default-user-settings-field-name
    * default-user-settings-field-email
    * initial-setup-field-password
    * initial-setup-field-password-repeat
27. Under `Validation Policies` select `password-complexity` and click `Update`

You can now go to `Directory->Invitations` and click `Create` to create an invitation link. Set a suitable name and expiration time. Make sure to select the `enrollment-invitation` flow and make sure `Single use` is checked. Expand the recently created invite and `Link to use the invitation` will contain the link to be distributed.

## 4. Applications setup
### API calls bypassing authentication
If you want to allow API calls to a certain application to bypass authentication simply add `^\/api\/.*` to `Advanced protocol settings->Unauthenticated Paths` under the relevant Provider.

### 4.1. Servarr
Authentik can be set up to contain the user//pass for the HTTP logins for the various Servarr apps and to forward credentials to the respective app after authentication via Authentik. This way you can keep authentication activated for each app but still only have to log in once when going through Authentik.

#### 4.1.1. Traefik changes
1. Go to your Traefik dir and open your `dynamic_config.yml`
2. Create a middleware similar to the one in the general Traefik setup above but including the `authorization` header (this is required for Authentik to be able to forward the credentials):
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
3. Optionally create a middleware chain similar to above:
    ```
    middlewares:
        authentik-http:
            chain:
                middlewares:
                    - authentik-auth-http
                    - default-security-headers
    ```

For the services where you want to use the HTTP-Basic authentication forwarding via Authentik you need to replace the default authentik middleware chain with the `authentik-http` created above instead.

#### 4.1.2. Authentik settings
1. Open the Authentik Admin Interface
2. Go to `Directory->Groups` and click `Create`
3. Set a suitable name, e.g. `Servarr Users`
4. Under `Attributes` input a list of usernames//passwords for the different Servarr apps, e.g.:
    - prowlarr_user: PROWLARR_USERNAME
    - prowlarr_password: PROWLARR_PASSWORD
    - sonarr_user: SONARR_USERNAME
    - sonarr_password: SONARR_PASSWORD
    - etc...
5. Click `Create`
6. Click on the recently created group, go to the `Users` tab and click `Add existing user`
7. Click the plus sign, select the users you want to be able to access the Servarr apps, click `Add` and then `Add` again
8. Go to `Applications->Providers` and click `Create`
9.  Select `Proxy Provider` and click `Next`
10. Set a suitable name, e.g. `Prowlarr Provider` and select `implicit-concent` under `Authorization flow`
11. Click `Forward auth (single application)`
12. Set `External host` to the externally accessible address for the app, e.g. `https://prowlarr.DOMAIN.COM`
13. Expand `Authntication settings` and make sure that both `Intercept header authentication` and `Send HTTP-Basic Authentication` are **ON**
15. Set `HTTP-Basic Username Key` and `HTTP-Basic Password Key` to `prowlarr_user` and `prowlarr_password` respectively (matching the keys in the list set up above)
16. Click `Finish`
17. *Repeat Provider creation for each individual app in your stack*
18. Go to `Applications->Applications` and click `Create`
19. Set a suitable name, e.g. `Prowlarr` and the slug similarly to `prowlarr`
20. Under `Provider` select the `Prowlarr Provider` created previously and click `Create`
21. *Repeat Application creation for each individual app in your stack*
22. Go to `Applications->Outposts` and open `authentik Embedded Outpost` for editing
23. Under `Applications` select each application created previously and click > to add them to `Selected Applications
24. Click `Update`
25. The previously created providers should now be listed in the `Providers` tab for `authentik Embedded Outpost`

### 4.2. Nextcloud
Authentik has a community integration for Nextcloud to allow user login and provisioning via Authentik.

#### 4.2.1. Authentik settings
Make sure usernames are immutable by going to `System->Settings` in the `Admin Interface` and checking that `Allow users to change username` is **OFF*.

1. Open the Authentik Admin Interface
2. Go to `Directory->Groups` and click `Create`
3. Create a group called `nextcloud_admins`, this will control which users are given admin permissions in `Nextcloud`
4. Create a group called `nextcloud_users`, this will control which users are allowed to access `Nextcloud` (to prevent Nextcloud accounts from being provisioned for users who aren't supposed to have access)
5. Go to `Customization->Property Mappings` and click `Create`
6. Select `Scope Mapping` and click `Next`
7. Set `Name` to `Nextcloud Profile` and `Scope name` to `profile`
8. In `Expression` enter the following:
   ```
    # Extract all groups the user is a member of
    groups = [group.name for group in user.ak_groups.all()]

    # Nextcloud admins must be members of a group called "admin".
    # This is static and cannot be changed.
    # We append a fictional "admin" group to the user's groups if they are a member of "nextcloud_admin in authentik.
    # This group would only be visible in Nextcloud and does not exist in authentik.
    if "nextcloud_admins" in groups:
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
9. Click `Finish`
10. Go to `Applications->Providers` and click `Create`
11. Select `OAuth2/OpenID Provider` and click `Next`
12. Enter the following:
    - Name: `Nextcloud Provider`
    - Authorization flow: implicit-consent
    - Client type: `Confidential`
    - Redirect URIs/Origins (RegEx): `https://nc.DOMAIN.COM/apps/user_oidc/code` (make sure you're using the correct path prefix)
    - Subject mode: `Based on the User's username`
13. Lastly under `Scopes` select `authentik default OAuth Mapping: OpenID 'email'` and `Nextcloud Profile` and make sure that `Include claims in id_token` at the bottom is **ON**
14. Take note of your `Client ID` and `Client Secret`, you will use this in the Nextcloud stage
15. Go to `Applications->Applications` and click `Create`
16. Enter the following:
    - Name: `Nextcloud`
    - Slug: `nextcloud`
    - Provider: `Nextcloud Provider`
17. Click `Create`
18. Click on the recently created application and go to the `Policy / Group/ User Bindings` tab and add the `nextcloud_users` group

To map an Authentik user to an existing Nextcloud account give the user an attribute like `nextcloud_user_id: NEXTCLOUD_ACCOUNT_NAME`. To give a user a quota limit give it an atrtibute like `nextcloud_quota: 10 GB`.

#### 4.2.2. Nextcloud settings
1. Log into the web UI using an admin account, click on the profile icon in the top-right and then click on `Apps`
2. Select the `Integration` category to the left and look for `OpenID Connect user backend`, enable it
3. Open `Unified search` by clicking the magnifying glass in the top-right and searching for `OpenID Connect`, click on the `Administration` entry
4. Click the plus sign under `Registered Providers` and enter the following:
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

### 4.3. Synology NAS
Authentik has a community integration for Synology DSM to allow user login via Authentik.

#### 4.3.1. Authentik settings
1. Open the Authentik Admin Interface
2. Go to `Applications->Providers` and click `Create`
3. Select `OAuth2/OpenID Provider` and click `Next`
4. Enter the following:
   - Name: Synology Provider
   - Authorization flow: implicit-consent
   - Client type: `Confidential`
   - Redirect URIs/Origins (RegEx): `https://nas.DOMAIN.COM/#/signin` (use whatever subdomain you set up in your Traefik dynamic_config.yml)
   - Subject mode: `Based on the User's username`
5. Click `Finish`
6. Go to `Applications->Applications` and click `Create`
7. Enter `Name`//`Slug` as `NAS`//`nas` and select the recently created provider, click `Create`

#### 4.3.2. Synology DSM settings
1. Log in to DSM with an admin account
2. Go to `Control Panel->Domain/LDAP` and click on the `SSO Client` tab
3. Check the `Enable OpenID Connect SSO service` box and click the `OpenID Connect SSO Settings` button below it
4. Enter the following:
   - Name: `Authentik`
   - Wellknown URL: `https://auth.DOMAIN.COM/application/o/nas/.well-known/openid-configuration`
   - Application ID: Client ID from the Synology Provider
   - Application Key: Client Secret from the Synology Provider
   - Redirect URL: `https://nas.DOMAIN.COM/#/signin`
   - Authorization scope: `openid profile email`
   - Username claim: `preferred_username`

Currently doesn't work properly with DSM <7.2 so TBC...