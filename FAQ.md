🙋🏻‍♂️ FAQ
========

1. **Why sticking to GitHub Actions instead of using GitHub Apps?**

    >[GitHub Apps][1] come with lots of advantages over GitHub Actions (e.g. they are not ephemeral, they use their own
    identity without the need for maintaing bots as separate users...) but are applications that you have to host
    somewhere. Unless eager developers out there will turn this automation into a GitHub App freely available in the
    [marketplace][2] 😉, we deem much more convenient to spare the burden of maitaining a local server and offload
    the service to the GitHub runners.
    
[1]: https://docs.github.com/en/developers/apps/about-apps
[2]: https://github.com/marketplace?type=apps

2. **Why does the dashboard repo need to be public to enable the [mentioning mechanism](/README.md#mentioning-a-group)?**

   >With a private dashboard repo, the action devoted to managing the mentioning mechanism would need an organization PAT
   to access the dashboard where all the required info is stored to correctly process the request. Relying on organization
   PATs represents a vulnerability as it may allow a user/contributor with `write` permissions to run a malicious action to
   take over the control of the organization.
   
