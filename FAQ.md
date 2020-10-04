🙋🏻‍♂️ FAQ
=======

1. **Why can't the workflow [`Trigger Mentioning Comment`][1] do the whole job within the org repo instead
  of passing the payload onto the dashboard repo?**

    >Org repos may be private and private workflows do consume monthly quota assigned for running GitHub Actions.
    Designing the org repo workflows sufficiently slim helps you keep such consumption limited and allows centralizing
    the main routine in a single public place.

1. **Why don't we use a webhook to trigger the "mentioning comment" workflow in place of the action?**

    >Currently, webhooks cannot trigger workflows. However, GitHub is cooking this feature since it's in the [roadmap][2].

1. **Why sticking to GitHub Actions instead of using GitHub Apps?**

    >[GitHub Apps][3] come with lots of advantages over GitHub Actions (e.g. they are not ephemeral, they use their own
    identity without the need for maintaing bots as separate users...) but are applications that you have to host
    somewhere. Unless eager developers out there will turn this automation into a GitHub App freely available in the
    [marketplace][4] 😉, we deem much more convenient to spare the burden of maitaining a local server and offload
    the service to the GitHub runners.

[1]: ./templates/.github/workflows/trigger-mentioning-comment.yml
[2]: https://github.com/github/roadmap/issues/52
[3]: https://docs.github.com/en/developers/apps/about-apps
[4]: https://github.com/marketplace?type=apps
