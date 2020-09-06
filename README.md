Automatically Manage Outside Collaborators Organization-wise
============================================================

## Intro
Unfortunately, GitHub does not provide (yet) a centralized way to manage outside collaborators within an organization,
although this [feature is very much requested][1]. As of now, outside collaborators can be handled only at the level
of the single repositories, having the main drawback of spreading in many places the knowledge of who can access what.

This undesired effect, of course, poses a problem of maintenance. If an external group of developers collaborates to
multiple repositories within an organization, what does it happen if the group evolves over time with new additions or
with members who leave? What if it is required to change their access permissions? In short, one must visit all the
repositories where such a collaboration takes place for checking and updating the corresponding information.

A possible workaround foresees to **invite outside collaborators to join a dedicated organization team**. This way,
we can benefit from the upsides we all know:
- teams are maintained within the central settings of the organization
- teams can be mentioned

Nonetheless, being a formal member of the organization may give the outside collaborators privileges when it comes
down to some specific access policies: for instance, if the [base permissions][2] of the organization is set to "Read"
instead of "None", then those collaborators will be able to clone and pull all repositories, private ones included!
Also, keeping the clear intended separation among organization members and outside collaborators is certainly
advantageous if we consider that we will prevent outside developers from inheriting future upcoming functionalities
that GitHub will design for org members and that can turn out to be disruptive when assigned to non-members.

A different solution to the problem is to implement an **automation of the handling of outside collaborators** within
an organization from a central "dashboard".

[1]: https://github.community/t/add-outside-collaborators-to-a-team-without-giving-them-acess-to-other-repos-in-an-organization/2396 
[2]: https://docs.github.com/en/github/setting-up-and-managing-organizations-and-teams/setting-base-permissions-for-an-organization

## How it works
### Components and Architecture
We make use of the following components:
- [GitHub Actions](https://docs.github.com/en/actions) for carrying out in the cloud the necessary jobs underlying
  the automation.
- [GitHub REST API](https://docs.github.com/en/rest) for querying and setting the information related to the outside
  collaborators.

The architecture relies on:
1. This repository acting as the **central dashboard**, that is where "groups" of outside collaborators (let's call
  them groups to differentiate from org teams) can be set up and modified using the mechanism of pull-requests.
1. A few **static information** stored within the single repositories where the collaboration takes place with the
  aim to assign specific access permissions to outside groups (or even individuals).

### The workflow
The "outside groups" are defined in YAML files under the subdirectory [groups](./groups) as collections of outside
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
```

Upon updating/adding/deleting those YAML files in the `master` branch or upon a [manual trigger][3], a GitHub
workflow starts crawling the organization to search for those repositories containing the static information
outlined in the previous section. For each single repository in this set, the outside collaborators are automatically
invited, removed or updated with the requested permissions stored in the repository.

Importantly, the groups files can be modified via pull-requests, enabling the responsible persons of the
outside collaborators (who are generally external to the organization) to keep their groups up-to-date. 

The static information is stored in the specific file of the repository called `.outside-collaborators/override.yml`,
whose an example is given below:

```yaml
lab_xyz/group01:
  type: "group"
  permission: "read"

lab_xyz/group02:
  type: "group"
  permission: "triage"

user06:
  type: "user"
  permission: "write"
```

Be aware of the following points:
- With specific keys, entries can represent groups but also individuals (e.g. `user06`), if there exists the
  requirement to deal with single outside collaborators within the repository.
- Only `"read"`, `"triage"` and `"write"` permissions are automatically handled. This way, malicious
  collaborators with `"write"` permission are unable to elevate themselves to become admins.
- Handling of outside collaborators on an individual basis takes over groups handling: e.g. `user06` ends up
  with `"write"` permission instead of `"triage"`, as for members of `lab_xyz/group02`.
- For security reasons, the file `.outside-collaborators/override.yml` should be managed by a repo maintainer
  who is also an org member, although it can be edited by outside collaborators with `"write"` permission.
- When an org repo contains the file `.outside-collaborators/override.yml`, the managing of its outside collaborators
  will be always overridden by the automatic workflow. Instead, org members can be still added/removed manually
  as inside collaborators.
- In certain circumstances, it might be still useful to deal manually with permissions of a specific outside
  collaborator: to this end, leave the field `permission` empty.

[3]: https://github.blog/changelog/2020-07-06-github-actions-manual-triggers-with-workflow_dispatch/

## Automation for your own organization

## Outro

### 👨🏻‍💻 Maintainers
This repository is maintained by:

| | |
|:---:|:---:|
| [<img src="https://github.com/pattacini.png" width="40">](https://github.com/pattacini) | [@pattacini](https://github.com/pattacini) |
