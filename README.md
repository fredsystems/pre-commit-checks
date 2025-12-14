# Pre-Commit Checks Flake

This repository provides a **unified, reusable Nix flake** that defines a standardized set of pre-commit checks for use across multiple repositories.

This is a work in progress.

It is designed to:

- Centralize linting logic
- Avoid duplication of `.pre-commit-config.yaml` across repos
- Allow consumers to **extend excludes** without overriding the base behavior
- Provide consistent, reproducible formatting and linting everywhere

---

## ✨ Features

### 🔧 Base pre-commit checks included

- YAML validation
- End‑of‑file fixer
- Mixed line ending fixer
- Trailing whitespace fixer
- Python (black, flake8)
- Nix (nixfmt, deadnix, statix)
- Shell (shellcheck)
- Dockerfiles (hadolint)
- Markdown / general formatting (prettier)
- Spell checking (codespell)
- GitHub Actions/workflow schema validation

### 🔌 Extensible Excludes

Repositories consuming this flake can **extend** the base exclusion list:

```nix
extraExcludes = [
  "^generated/"
  "^dist/"
  "^third-party/"
];
```

This allows per‑repo customization without duplicating config.

---

## 📦 Usage (Consumer Repository)

Add the flake:

```nix
inputs.precommit-base.url = "github:FredSystems/pre-commit-checks";
inputs.nixpkgs.follows = "precommit-base";
```

Then define a check in your flake:

```nix
checks.pre-commit =
  precommit-base.lib.mkPrecommitCheck {
    system = builtins.currentSystem;
    src = ./.;

    extraExcludes = [
      "^dist/"
      "^generated/"
    ];
  };
```

Run it with:

```sh
nix flake check
```

---

## 🧪 Development Shell (for this flake)

This repository provides its own development shell via:

```sh
nix develop
```

Includes tools such as:

- pre-commit
- deadnix
- statix
- nixfmt
- codespell
- markdownlint

---

## 🏗️ Architecture Overview

```bash
pre-commit-checks/
 ├── flake.nix
 └── README.md  ← you are here
```

### Exported API

| Attribute              | Description                                             |
| ---------------------- | ------------------------------------------------------- |
| `lib.mkPrecommitCheck` | Main function for generating per‑repo pre-commit checks |

---

## 📄 License

MIT License unless otherwise stated.

---

## 🤝 Contributing

Issues and PRs are welcome!
If you want additional hook bundles (Rust, Python, Go), open an issue.

---

## 💬 Support

Ping me anytime—happy to help you wire this into your repos!
