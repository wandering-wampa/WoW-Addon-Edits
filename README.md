# WoW Addon Edits

Personal World of Warcraft addon customizations maintained by wandering-wampa.

## Download and install

Download the addon ZIP from the [latest release](https://github.com/wandering-wampa/WoW-Addon-Edits/releases/latest). In CurseForge, choose **Open Addons Folder**, then extract the ZIP into that folder. The ZIP contains the addon folder directly, such as `ConcentrationTracker_Edit/ConcentrationTracker_Edit.toc`; do not add an extra nested folder. Restart WoW for a new addon, or `/reload` after replacing an existing copy.

Download the release asset rather than GitHub's automatic **Source code** archives. CurseForge updates can overwrite these customizations.

New changes to addon files on `main` automatically publish fresh installable ZIPs. To package locally, run `python tools/package_addons.py`; archives appear under `local-work/dist/`.

## Addons

| Addon | Customizations and setup |
| --- | --- |
| Concentration Tracker | [README](addons/ConcentrationTracker_Edit/README.md) â€” Retail UI styling, responsive meters, alt concentration tracking, and sorting. |

Each addon lives under `addons/<AddonName>/` and has its own README covering its changes, installation, commands, validation, and upstream attribution.

## Development


Keep the repository copy and the installed WoW addon in sync. After making and checking requested changes, update the relevant addon README when needed, commit the changes, and push to `main`. See [AGENTS.md](AGENTS.md) for the working instructions.

Addon-manager updates can overwrite customizations. Review upstream updates before replacing edited files. Keep account data, SavedVariables, logs, and credentials out of this repository.

## Rights

This repository is public. Upstream authors retain their rights; check each addon's README for attribution and license details. No blanket license is applied to the collection.
