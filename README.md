# CorvusPKG AKA VoidForge

**A lightweight package management and dependency inspection toolkit for Void Linux.**

<p align="center">

  **Made by Corvus**

  [GitHub](https://github.com/Yamen1294)

</p>

---

## Overview

CorvusPKG is a Bash-based command-line toolkit designed for Void Linux. It provides a convenient way to inspect installed packages, explore dependency relationships, identify orphaned packages, and safely remove packages along with their unneeded dependencies.

Built around the XBPS package management system, CorvusPKG offers both an interactive terminal interface and direct command-line operations.

The goal is simple: make package management more transparent by giving users a clearer understanding of their installed packages and their dependency relationships.

## Features

- **Package inspection:** List installed packages and inspect individual packages.
- **Dependency analysis:** Display direct and recursive dependencies.
- **Reverse dependency analysis:** Identify packages that depend on a selected package.
- **Installation tracking:** Distinguish manually installed packages from automatically installed dependencies.
- **Orphan detection:** Count installed packages classified as orphans by XBPS.
- **Safe removal:** Preview packages scheduled for removal before proceeding.
- **Dependency protection:** Refuse removal when other installed packages depend on the selected package.
- **Interactive interface:** Navigate package operations through a simple terminal menu.
- **Command-line support:** Execute operations directly without using the interactive menu.
- **Confirmation control:** Support automatic confirmation through `--yes`.

## Requirements

CorvusPKG is designed for **Void Linux**.

Required components:

| Requirement | Purpose |
|---|---|
| Bash | Script execution |
| XBPS | Package management and dependency queries |
| awk | Text processing |
| sed | Text transformation |
| sort | Sorting package lists |
| sudo or doas | Privileged package removal when running as a regular user |

`less` is optional and used for paginated terminal output.

## Installation

### 1. Obtain the project

Download or clone the repository and navigate to its directory.

### 2. Make the script executable

```bash
chmod +x voidpkg.sh
```

### 3. Run CorvusPKG

```bash
./voidpkg.sh
```

Alternatively:

```bash
bash voidpkg.sh
```

## Usage

CorvusPKG supports two operation modes:

1. Interactive mode.
2. Command-line mode.

### 1. Interactive mode

Start the program without arguments:

```bash
./voidpkg.sh
```

The interactive menu provides the following options:

```text
=== CorvusPKG — Void Linux Package Toolkit ===

  1) List installed packages and their dependencies
  2) Remove a package and its dependencies
  q) Quit

Select an option [1/2/q]:
```

**Option 1 — List packages**

Displays installed packages and their direct dependencies.

You can also enter a specific package name to inspect its dependency relationships.

**Option 2 — Remove packages**

Select a package to remove.

CorvusPKG checks reverse dependencies, displays a removal preview, and requests confirmation before executing the removal operation.

### 2. Command-line mode

You can execute operations directly without opening the interactive menu.

#### List installed packages

```bash
./voidpkg.sh list
```

Displays installed packages and their direct dependencies.

#### Inspect a specific package

```bash
./voidpkg.sh list firefox
```

Displays:

- Package name.
- Installation reason.
- Number of direct dependencies.
- Total number of recursive dependencies.
- Packages that depend on the selected package.

#### Remove a package

```bash
./voidpkg.sh remove firefox
```

The removal process:

1. Checks whether the package is installed.
2. Checks whether other installed packages depend on it.
3. Executes an XBPS dry run.
4. Displays the proposed removal.
5. Requests confirmation.
6. Executes the removal if approved.

**Important:** CorvusPKG refuses to remove a package if installed packages depend on it.

#### Count installed and orphan packages

```bash
./voidpkg.sh --count
```

Or:

```bash
./voidpkg.sh -count
```

Displays the total number of installed packages and the number of orphan packages reported by XBPS.

## Command Reference

| Command | Description |
|---|---|
| `./voidpkg.sh` | Launch interactive mode |
| `./voidpkg.sh list` | List installed packages |
| `./voidpkg.sh list PACKAGE` | Inspect a specific package |
| `./voidpkg.sh remove PACKAGE` | Remove a package and unneeded dependencies |
| `./voidpkg.sh --count` | Count installed and orphan packages |

## Options

| Option | Description |
|---|---|
| `-y`, `--yes` | Skip removal confirmation prompts |
| `-count`, `--count` | Display installed and orphan package counts |
| `-h`, `--help` | Display help information |
| `-V`, `--version` | Display the script version |

Examples:

```bash
./voidpkg.sh --help
./voidpkg.sh --version
./voidpkg.sh --count
./voidpkg.sh remove firefox --yes
```

**Warning:** `--yes` skips the interactive confirmation. Review removal operations carefully before using it.

## Understanding Dependency Types

CorvusPKG provides three different dependency perspectives.

### Direct Dependencies

Packages directly required by the selected package.

### Recursive Dependencies

The complete transitive dependency set discovered by following dependency relationships.

For example:

```text
Package A
 ├── Package B
 │    ├── Package D
 │    └── Package E
 └── Package C
      └── Package F
```

The recursive dependency set includes B, C, D, E, and F.

### Reverse Dependencies

Packages that require the selected package.

This is particularly useful when determining whether removing a package could affect other installed software.

## Orphan Packages

An orphan package is a package that XBPS identifies as no longer required by other installed packages.

CorvusPKG uses:

```bash
xbps-query -O
```

To retrieve the orphan package list and calculate its size in terms of package count.

You can inspect the count using:

```bash
./voidpkg.sh --count
```

## Safety Considerations

Package removal can affect the functionality of your operating system.

CorvusPKG includes several safeguards:

- Checks whether the requested package is installed.
- Checks reverse dependencies before removal.
- Performs a dry run before executing removal.
- Displays the proposed removal operation.
- Requests user confirmation by default.
- Supports `sudo` and `doas` for privileged operations.

**Always review the proposed package removal before confirming.**

A dry run is a preview, not a guarantee that every possible system-level consequence has been identified.

## Project Structure

```text
CorvusPKG/
│
├── voidpkg.sh
├── README.md
├── LICENSE
└── .gitignore
```

## License

This project is licensed under the **Apache License 2.0**.

You are permitted to:

- Use the software for personal or commercial purposes.
- Modify the source code.
- Distribute original or modified versions.
- Include the software in other projects.

You must preserve applicable original copyright and attribution notices. Modified files must identify that changes were made, as required by the license.

See the [LICENSE](LICENSE) file for the complete license terms.

## Author

Originally created and maintained by **Corvus**.

GitHub: https://github.com/Yamen1294

## Attribution

You are free to use, modify, and redistribute this project under the Apache License 2.0.

Original copyright notices and attribution notices must be preserved.

Modified versions must clearly identify their modifications and must not misrepresent the original authorship.

**Corvus remains credited as the original author of this project.**

---

<p align="center">

  **CorvusPKG**

  Built with Bash for Void Linux.

  Made by **Corvus**.

  [GitHub Profile](https://github.com/Yamen1294)

</p>
