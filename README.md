# docker-authentik
Docker container for use as Identity Provider and authentication portal in front of a Traefik reverse-proxy

## Docker Setup
1. Initialize config by running init.sh: `./init.sh`
1. Input personal information into `.env`
1. Generate postgresql password and authentik secret key, by using e.g. `openssl rand 56 | base64`, and input into `./secrets/POSTGES_PASSWORD.secret` and `./secrets/AUTHENTIK_SECRET_KEY.secret` respectively
1. Make sure that Docker network `traefik` exists, `docker network ls`
1. Run `docker compose up` and check logs

## Authentik Setup (Written for version 2024.4.2)
### Set up your first user
1. Open browser and go to `auth.YOURDOMAIN.COM` and verify that you reach the Authentik login screen
1. Add `/if/flow/initial-setup/` at the end of the URL to reach the dialogue for setting up the initial admin account
1. Input the email and password you want to use for the default `akadmin` account and press `Continue`
1. Log into the default admin account using either usename `akadmin` or the email you entered in the previous step
1. Click the `Admin interface` button on the top-right
1. Go to `Directory->Users` in the menu on the left side and click `Create`
1. Input `Username` and `Name`, select `User type: Internal`, input `Email`, finally click Create
1. Click on your recently created user and go to the `Groups` tab and click `Add to existing group`
1. Click on the plus sign, select `authentik Admins` and press `Add`, then press `Add` again
1. Log out of the current session and log in with your new user account instead
1. Go back to `Directory->Users` and click on the `akadmin` user
1. In the `User Info` pane scroll down to the `Actions` section and press the `Deactivate` button, then press `Update` in the popup prompt

You have now logged in for the first time, created your own user account and disabled the default admin account.

### Configuring Authentik Embedded Outpost
1. In the `Admin interface`, go to `Applications->Outposts`, locate the `authentik Embedded Outpost` and verify that is says `Loggin in via https://auth.YOURDOMAIN.COM` in green below the name
1. Go to `Applications->Providers` and click `Create`
1. Select `Proxy Provider` and click `Next`
1. Input a `Name`, e.g. `Traefik Provider` and select `Authorization flow` with either implicit or explicit consent (determines if you are presented with an explicit prompt when being forwarded after logging in or not)
1. Click `Forward auth (domain level)`, check that `Authentication URL` is `https://auth.YOURDOMAIN.COM` and set `Cookie domain` simply as `YOURDOMAIN.COM`
1. Change `Token validity` to your taste and click `Finish`
1. Go to `Applications->Applications` and click `Create`
1. Input `Name` and `Slug`, e.g. `Traefik`//`traefik`
1. Click the `Provider`field and select `Traefik Provider` (or whatever you named it in the previous step) and finally click `Create`
1. Go back to `Applications->Providers` and verify that `Traefik Provider` has a green checkmark and the text `Assigned to application Traefik` under the `Àpplication` column
1. Go back to `Applications->Outposts` and click the  `Edit` button for the `authentik Embedded Outpost` (under the `Actions` column)
1. In the `Applications` section click on `Traefik` and press the > button to add it to `Selected Applications`, then press `Update`

You have now set up Authentik to be ready to be used with Traefik reverse-proxy with domain level forward auth

### Configuring Traefik
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

Now you can use Authentik together with Traefik by including the authentik middleware in container labels, e.g.: `traefik.http.routers.APP_NAME.middlewares=authentik@file`

## Autentik configuration
### Check if email config is correct
To verify that the email settings in `.env` are correct run `docker compose exec worker ak test_email RECIPIENT_EMAIL` to send a test email to `RECIPIENT_EMAIL`

### Showing both username and password prompt at once on login screen
Certain password managers will have an easier time auto-typing your login info if the username and password fields are both presented at once

1. Go to `Flows and Stages->Flows` and click `Edit Stage` for the `default-authentication-identification` stage
1. Under `Password stage` select `default-authentication-password` and click `Update`
1. Delete `default-authentication-password`

### Password complexity policy
It's a good idea to enforce some kind of password policy

1. Go to `Customisation->Policies` and click `Create`
1. Select `Password Policy`and click `Next`
1. Set a suitable `Name`, e.g. `password-complexity`
1. Expand the `Static rules` section
1. Input your choice of rules and enter an `Error message` that reflects the requirements, e.g. `Please enter a minimum of 12 characters with at least 1 uppercase, 1 lowercase, 1 digit and 1 symbol.`

### MFA forced on login
It's a good idea to enforce MFA for something that provides such powerful means of access. Here's how to force setup of MFA using TOTP using e.g. Google Authenticator app

1. Go to `Flows and Stages->Flows`, click on `default-authentication-flow` and go to the `Stage Bindings` tab
1. Click `Bind existing stage`, for `Stage` select `default-authentication-mfa-validation` stage and set `Order` to `30`
1. Click `Edit Stage` for `default-authentication-mfa-validation`
1. Under `Stage-specific settings->Device classes` select the MFA types you want to allow, in this case only `TOTP Authenticators` for Google Authenticator app
1. Set `Not configured action` to `Force the user to configure an authenticator`
1. Under `Configuration stages` select only `default-authenticator-totp-setup`, click `Update`

### Password recovery
If users forget their password it's nice if they're able to reset their passwords on their own

1. Go to `Flows and Stages->Stages` and click `Create`
1. Select `Identification Stage` and click `Next`
1. Set a suitable name, e.g. `recovery-authentication-identification`, select `User fields` `Username` and `Email` and click `Update`
1. Click `Create` again and select `Email Stage`, click `Next`
1. Set a suitable `Name`, e.g. `recovery-email`
1. Set `Subject` to `Password Recovery`
1. Go to `Flows and Stages->Flows` and click `Create`
1. Set `Name`/`Title`/`Slug` as `Recovery`/`Recovery`/`recovery`
1. Set `Designation` as `Recovery`
1. Click `Create`
1. Click on the `recovery` flow we just created and go to the `Stage Bindings` tab
1. Add bindings by clicking `Bind existing stage` and setting up according to the table below:

    | Order | Stage |
    | ----: | :---- |
    | 10 | recovery-authentication-identification |
    | 20 | recovery-email |
    | 30 | default-password-change-prompt |
    | 40 | default-password-change-write |

1. Click on `Edit Stage` for the `default-password-change-prompt` stage
1. Under `Validation Policies` select `password-complexity` and click `Update`
1. Click on `Edit Stage` for the `default-authentication-identification` stage
1. Under `Flow settings->Recovery flow` select `Recovery` and click `Update`

### Invitation
It's a bad idea to allow anyone visiting the login page to register for an account. Invitation link with a set expiration time is a better solution

1. Go to `Directory->Groups` and click `Create`
1. Set a suitable name, e.g. `authentik Users`
1. Make sure `Is superuser` is switched **OFF**, click `Create`
1. Click on your recently created group, go to the `Users` tab and click on `Add existing user`
1. Click on the plus sign, select your currently existing normal user accounts, press `Add` and then press `Add` again
1. Go to `Flows and Stages->Stages` and click `Create`
1. Select `User Write Stage` and click `Next`
1. Set a suitable name, e.g. `enrollment-invitation-write`
1. Under `Stage-specific settings` make sure `Create users when required` is selected and uncheck `Create users as inactive`
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

    | Order | Stage |
    | ----: | :---- |
    | 10 | enrollment-invitation |
    | 20 | default-source-enrollment-prompt |
    | 30 | enrollment-invitation-write |
    | 40 | enrollment-invitaion-email |
    | 50 | default-source-enrollment-login |

1. Click on `Edit Stage` for the `default-source-enrollment-prompt` stage
1. Under `Stage-specific settings->Fields` select the following entries:
    * default-user-settings-field-username
    * default-user-settings-field-name
    * default-user-settings-field-email
    * initial-setup-field-password
    * initial-setup-field-password-repeat
1. Under `Validation Policies` select `password-complexity` and click `Update`

You can now go to `Directory->Invitations` and click `Create` to create an invitation link. Set a suitable name and expiration time. Make sure to select the `enrollment-invitation` flow and make sure `Single use` is checked. Expand the recently created invite and `Link to use the invitation` will contain the link to be distributed