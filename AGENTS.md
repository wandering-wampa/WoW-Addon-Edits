# Working instructions

## User preference: sync every addon change to GitHub

The user explicitly requests that all future addon changes made as part of our work be committed and pushed to https://github.com/wandering-wampa/WoW-Addon-Edits.

- Repository: use the current checkout of wandering-wampa/WoW-Addon-Edits.
- Remote: `origin`; branch: `main`; the user explicitly requested that the repository be public.
- Locate the intended WoW Retail Interface/AddOns directory on the current machine before deployment.
- Editable addon sources belong in `addons/<AddonName>/` in this repository.
- Before editing, inspect Git status and compare the relevant installed files with the repository copy. Preserve unrelated or newer user changes; do not blindly overwrite them.
- Make requested changes, run appropriate checks, and synchronize the edited addon files between the repository and the installed game folder. Verify that deployed files match the repository copy.
- For each completed addon change, update its documentation as needed, commit the relevant files with a descriptive message, and push to origin/main. This is standing user authorization; do not ask again solely to commit or push. Follow any required tool approval process.
- Verify the remote commit matches the local commit. If authentication, network access, permissions, or merge conflicts block a push, report it clearly; never claim an unpushed change is backed up.
- Never commit SavedVariables, account data, credentials, caches, logs, or temporary test assets. Never force-push or discard unrelated changes.

## Documentation

- The root README is a concise collection overview and links to each addon README.
- Each `addons/<AddonName>/README.md` describes that addon's custom changes, installation, commands, validation, limitations, and upstream attribution.
- Preserve original upstream documentation as `UPSTREAM-README.md` when replacing an upstream README with our customization guide.
- Preserve upstream authorship and licensing. Do not add a repository-wide license that purports to relicense upstream code.

## Concentration Tracker

- Preserve opaque Retail styling, the corrected shared table margin, responsive bars, damage-meter artwork, working minimap placement, login discovery, and four-way character/class sorting unless explicitly asked to change them.
- Login scans must read the logged-in character's live currency values, never copy another character's quantities.
- Validate actual refresh and row-reuse paths when changing UI layout; they can override initial anchors.

## Release packaging

- Keep release ZIPs directly extractable into Interface/AddOns: `<AddonName>/<AddonName>.toc`, without repository or `addons/` wrapper folders.
- Run `python tools/package_addons.py` when preparing addon downloads. The packaging workflow publishes fresh ZIPs after addon changes are pushed to main. Verify its result before reporting a new downloadable build.

## Edited addon names

- Name all edited addons `<OriginalAddonName>_Edit`, including the repository folder, installation folder, primary TOC basename, release ZIP, and addon-list title.
- Current addon: `addons/ConcentrationTracker_Edit/ConcentrationTracker_Edit.toc`. The existing original-named installed folder is a legacy installation until the user migrates with WoW closed.
- Retain SavedVariables global names and original authorship; renaming an addon changes the SavedVariables filename. Document migration and never run original and edited copies together when they share globals.

## Public repository privacy

- Never commit machine-specific absolute paths, local usernames, hostnames, account identifiers, screenshots, personal setup details, or local scratch-file inventories. Use repository-relative paths and generic installation instructions.
- Keep machine-specific instructions only in ignored local files. Inspect staged content and release archives for accidental disclosures before pushing.
