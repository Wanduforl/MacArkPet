# Legal And Distribution Notes

This document is a practical compliance checklist for MacArkPet maintainers and
packagers. It is not legal advice.

## Source Code License

MacArkPet source code is released under the GNU General Public License v3.0.

The upstream Ark-Pets project is also licensed under GPL-3.0 and its README
asks derivative users to keep the author notice, keep the original license, and
open source under the same license. MacArkPet follows that requirement by:

- using the GNU GPL v3.0 license text in `LICENSE`
- preserving Ark-Pets attribution in `README.md`, `NOTICE.md`, and
  `THIRD_PARTY_NOTICES.md`
- keeping MacArkPet source code public under GPL-3.0
- avoiding extra source-code license restrictions such as "non-commercial only"

GPL-3.0 does not allow adding extra restrictions to the source code license.
Do not reintroduce a custom non-commercial source-code license.

## Fork Status

GPL-3.0 does not require a GitHub repository to be created with GitHub's `Fork`
button. The legal requirements are about license, source availability, notices,
and preserving recipients' GPL rights.

However, if this repository substantially tracks or derives from Ark-Pets, using
GitHub's fork relationship is clearer for attribution and reduces confusion.
When possible, publish MacArkPet from a GitHub fork of
`isHarryh/Ark-Pets`.

## Game Assets And Model Resources

This repository and release app bundle must not include Arknights game assets,
character models, atlas files, skeleton files, or generated model packages.

MacArkPet may let a user download model resources at runtime from the community
Ark-Models repository. The app and documentation must keep this distinction
clear:

- bundled MacArkPet source/app code is GPL-3.0
- downloaded model resources are not owned by MacArkPet
- users are responsible for complying with the relevant rights holders' terms
- redistributed builds must not pre-bundle downloaded game/model assets

## Spine Runtime

MacArkPet includes `Resources/spine-webgl.js`, which is governed by the Spine
Runtimes License Agreement, not GPL-3.0. Release bundles must include
`Resources/spine-ts-LICENSE` and `THIRD_PARTY_NOTICES.md`.

Before changing the Spine runtime or redistributing modified runtimes, review
the current Spine Runtimes terms from Esoteric Software.

## GitHub Distribution Hygiene

Before publishing a release:

- confirm `LICENSE` is GNU GPL v3.0
- confirm `README.md`, `NOTICE.md`, and `THIRD_PARTY_NOTICES.md` attribute
  Ark-Pets and Ark-Models
- confirm release bundles include `LICENSE`, `NOTICE.md`, and
  `THIRD_PARTY_NOTICES.md`
- confirm no model resource directories are included in the repository or app
  bundle
- confirm old release assets with incorrect license text are removed or clearly
  superseded

## References

- Ark-Pets: https://github.com/isHarryh/Ark-Pets
- Ark-Models: https://github.com/isHarryh/Ark-Models
- GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.en.html
- GitHub licensing docs: https://docs.github.com/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository
- GitHub fork docs: https://docs.github.com/get-started/quickstart/fork-a-repo
- GitHub DMCA policy: https://docs.github.com/site-policy/content-removal-policies/dmca-takedown-policy
