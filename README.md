# Aura TouchDesigner Project

This repository contains the main TouchDesigner project and supporting assets for visual development.

## Repository Contents

- `aura_main.toe` - main TouchDesigner project file
- `scripts/` - Python logic and wrappers
- `components/` - reusable `.tox` components
- `tools/` - utility `.tox` tools
- `shaders/` - GLSL shaders used by the project

## Branching Workflow (Required)

To keep `main` stable and clean:

- **Do not work directly in `main`**
- **Do not merge local work directly into `main`**
- Each developer must work only in their own branch (for example: `vis_dev`, `feature/<name>`, `fix/<name>`)
- Changes go to `main` only through Pull Requests
- Rebase or merge `main` into your own branch regularly to stay up to date

## Suggested Daily Flow

1. Update local `main`:
   - `git checkout main`
   - `git pull origin main`
2. Switch to your branch:
   - `git checkout <your-branch>`
3. Develop and commit changes in your branch
4. Push your branch:
   - `git push origin <your-branch>`
5. Open a Pull Request into `main`

## Collaboration Rule

`main` should always represent a releasable, verified state.  
All experiments, WIP changes, and feature development stay in personal branches until reviewed.
