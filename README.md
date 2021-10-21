Automatically Manage Outside Collaborators Organization-wide
============================================================

## ℹ Intro
Unfortunately, GitHub does not provide (yet) a centralized way to manage outside collaborators within an organization,
although this [feature is very much requested][feature-request]. As of now, outside collaborators can be handled only
at the level of the single repositories, having the main drawback of spreading in many places the knowledge of who can
access what.

This undesired effect poses a problem of maintenance. If an external group of developers collaborates to multiple
repositories within an organization, what happens if the group evolves over time with new additions or with members
who leave? What if it is required to change their access permissions? In short, one must visit all the repositories
where such a collaboration takes place for checking and updating the corresponding information.

A possible workaround foresees to **invite outside collaborators to join a dedicated organization team**. This way,
we can take advantage of the perks we all know:
- teams are maintained within the central settings of the organization
- teams can be mentioned

Nonetheless, being a formal member of the organization may give the outside collaborator privileges when it comes
down to some specific access policies. For instance, if the [base permissions][base-permissions] of the organization
is set to `"Read"` instead of `"None"`, then that collaborator will be able to clone and pull all repositories,
private ones included!

Also, keeping the clear separation among organization members and outside collaborators is certainly advantageous
if we consider that we will prevent outside developers from inheriting future upcoming functionalities
that GitHub will design for org members and that can turn out to be disruptive when assigned to "unintended" members.

A different solution to the problem is to implement an **automated workflow for handling outside collaborators** within
an organization from a central "dashboard" repo.

## ⚡ How it works
### Components and Architecture
We make use of the following components:
- [GitHub Actions](https://docs.github.com/en/actions) for carrying out in the cloud the necessary jobs underlying
  the automation.
- [GitHub REST API](https://docs.github.com/en/rest) for querying and setting the information related to the outside
  collaborators.

The architecture relies on this repository acting as the **central dashboard** where:
1. "groups" of outside collaborators (let's call them _groups_ to differentiate from org teams) can be set up and
   modified using the mechanism of pull-requests.
1. permissions to access those repositories where the collaboration takes place ("automated repositories") are
   stored and used to override the standard methodology.

### The workflow
The "outside collaborators groups" are defined in YAML files under [`groups`](./groups) as collections of outside
collaborators' usernames.

Here's a simple example:

```yaml
lab_xyz/group01:
  - "user01"
  - "user02"
  - "user03"

lab_xyz/group02:
  - "user04"
  - "user05"
  - "user06"

generic-group:
  - "user07"
  - "user08"
```

Likewise, access permissions to automated repositories are defined in YAML files under [`repos`](./repos) as in the
following example:

```yaml
repo_name_1:
  lab_xyz/group01:
    type: "group"
    permissions: "read"

  lab_xyz/group02:
    type: "group"
    permissions: "triage"

  user06:
    type: "user"
    permissions: "write"

repo_name_2:
  lab_abc/group01:
    type: "group"
    permissions: "write"

  user07:
    type: "user"
    permissions: "maintain"
```

Upon updating those YAML files in the default branch via [forks and pull requests][forks-prs] or upon a
[manual trigger][manual-trigger], a GitHub workflow propagates the changes to the automated repositories.
In detail, for each automated repo, the outside collaborators are automatically invited, removed or updated
with the requested permissions.

Importantly, the YAML files can be modified via pull-requests, enabling the representatives responsible for the
outside collaborators (who are generally external to the organization) to keep their groups up-to-date.
In addition, pull-requests have to be reviewed by org members, thus ensuring that the process can run securely.

Pay attention to the following points:
- The name of the automated repositories in the YAML files shall not contain the organization (i.e. the repository
  owner).
- With specific keys, entries can represent groups but also individuals (e.g. `user06`), if there exists the
  requirement to deal with single outside collaborators within the repository.
- Handling of outside collaborators on an individual basis takes over groups: e.g. for the repo `repo_name_1`,
  the user `user06` ends up with `"write"` permissions instead of `"triage"`, as it should have been instead
  for being a member of `lab_xyz/group02`.
- If a user belongs to multiple groups that are all assigned to a single specific repository, then that user
  will end up receiving permissions according to how those groups get sequentially processed by the automation.
  To get around this, just handle that user on an individual basis.
- The managing of outside collaborators of an automated repo will be always overridden by the automatic workflow.
  Instead, org members can be still added/removed manually as inside collaborators.
- You can use [YAML anchors and aliases][yaml-anchors] to streamline the content of the files.

### Mentioning a group
Anyone posting a message in an issue or a PR of a org repository where the outside collaborators automation is
established can mention a group using the following _bash-like_ convention:
- `$group-name`
- `${group-name}`

For example, if `user01` posts:
```markdown
Hey ${lab_xyz/group01} 👋🏻
I've got an exciting news to share with you!
```

Then, GitHub will reply with:
```markdown
>Hey lab_xyz/group01 👋🏻
>I've got an exciting news to share with you!

@user01 wanted to notify the following collaborators:

@user02 @user03
```

To avoid cluttering the thread, the original triggering message is quoted only up to a given extent.

### Removing entries from [`repos`](./repos)
When a repo entry gets removed from [`repos`](./repos), the subsequent action won't be able to perform
any cleanup of the corresponding repository as the entry is simply missing and thus the action won't
find it out. To circumvent this, leave the entry empty for one round to give the action the possibility
to perform the required cleanup. Soon afterward, the entry can be safely removed.

There are other smarter ways to get it done automatically (e.g. by comparing `HEAD` against `HEAD~`)
but this is actually the simplest. Also, consider that if an entry is no longer declared, then it is
semantically correct that the automation does no longer handle it.   

Obviously, one can also perform a manual cleanup straight away.

### Cleaning up stale invitations
[Pending invitations self-expire after a few days](https://docs.github.com/en/organizations/managing-membership-in-your-organization/inviting-users-to-join-your-organization).

It may happen that certain invitees do not want to join the intended repositories as external
collaborators. In this regard, we do not clean up automatically stale invitations to use them as
indicators that we shall not spam those invitees with continuous requests at every automation run.

However, it might be convenient sometimes to clean up stale invitations on demand. To this end,
one can rely on the manually-triggered workflow [`Delete Invitations`](./.github/workflows/delete-invitations.yml).

## ⚙ Automation for your organization
Follow the quick guide below if you want to install this automation in your organization:
1. [Create a copy](../../generate) of this dashboard repository in your organization account.
   To use the [mentioning mechanism](#mentioning-a-group) (optional), it is required to keep this repo **public**.
1. Make sure that **only org admins can manage the dashboard** repository.
1. One org admin is required to create a **personal access token** (PAT) with full repo scope.
1. Ceate in the dashboard a **secret** called `OUTSIDE_COLLABORATORS_TOKEN` where to store the admin PAT.
   This PAT will allow the automation to modify the organization repositories.
1. Enforce the use of a [GitHub environment][gh-environment] to guarantee security when checking PRs from external forks.
   Jobs referring to environments can start only if approved by specific reviewers.
1. Edit the initial content of [`groups`](./groups).
1. For each single repo of your org you aim to apply automation to, do:
    - Create the corresponding file in [`repos`](./repos) and add up the entries according to your needs.
    - **Optionally**, if you aim to enable the [mentioning mechanism](#mentioning-a-group), copy out the
      content of [`templates`](./templates) into the repository while preserving the files paths.

✨ You are finally good to go! Remember to manage the update of the outside collaborators through [pull requests][pull-requests].

## ⚠ Known limitations/issues
- We are required to comply with the GitHub API [rate limit rules][rate-limit]. In case we hit such a limit,
  the automation will wait for the reset to take place. To alleviate this, one can follow
  [@JeroenKnoops](https://github.com/JeroenKnoops)'s [suggestion][gh-app-suggestion] and use a GitHub App
  to perform API calls.
- The dashboard repository is required to be **public** in order to enable the [mentioning mechanism](#mentioning-a-group).
  See [FAQ](./FAQ.md) for more details.
- Pending [known bugs][known-bugs] 🐛

## 🔳 Outro
We hope that you will find this workflow helpful!

Contributions that improve the automation are more than welcome.

## [🙋🏻‍♂️ FAQ](./FAQ.md)

## 👨🏻‍💻 Maintainers
This repository is maintained by:

| | |
|:---:|:---:|
| [<img src="https://github.com/pattacini.png" width="40">](https://github.com/pattacini) | [@pattacini](https://github.com/pattacini) |

[feature-request]: https://github.community/t/add-outside-collaborators-to-a-team-without-giving-them-acess-to-other-repos-in-an-organization/2396 
[base-permissions]: https://docs.github.com/en/github/setting-up-and-managing-organizations-and-teams/setting-base-permissions-for-an-organization
[forks-prs]: https://guides.github.com/activities/forking
[manual-trigger]: ../../actions?query=workflow%3A%22Update+Outside+Collaborators%22
[gh-environment]: ./.github/workflows/check-automated-repositories.yml#L22
[rate-limit]: https://docs.github.com/en/free-pro-team@latest/rest/overview/resources-in-the-rest-api#rate-limiting
[gh-app-suggestion]: ../../issues/22#issuecomment-772079850
[known-bugs]: ../../issues?q=is%3Aopen+is%3Aissue+label%3Areport-bug
[yaml-anchors]: https://support.atlassian.com/bitbucket-cloud/docs/yaml-anchors
[pull-requests]: ../../pulls?q=is%3Apr
