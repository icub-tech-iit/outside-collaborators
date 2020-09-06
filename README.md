Automatically Manage Outside Collaborators Organization-wise
============================================================

# Intro
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

Nonetheless, being a formal member of the organization may give the external collaborators privileges when it comes
down to some specific access policies: for instance, if the base permissions of the organization is set to "Read"
instead of "None", then those collaborators will be able to clone and pull all repositories, private ones included!
Also, keeping the clear intended separation among organization members and outside collaborators is certainly
advantageous if we consider that we will prevent outside developers from inheriting future upcoming functionalities
that GitHub will design for org members and that can turn out to be disruptive when assigned to non-members.

A different solution to the problem is to implement an **automation of the handling of outside collaborators** within
an organization from a central "dashboard".


[1]: https://github.community/t/add-outside-collaborators-to-a-team-without-giving-them-acess-to-other-repos-in-an-organization/2396 

### 👨🏻‍💻 Maintainers
This repository is maintained by:

| | |
|:---:|:---:|
| [<img src="https://github.com/pattacini.png" width="40">](https://github.com/pattacini) | [@pattacini](https://github.com/pattacini) |
