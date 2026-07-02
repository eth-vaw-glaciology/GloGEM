# Git Workflow

GloGEM uses Git for version control with GitHub as the remote host. The code and documentation live in one repository, on a single `main` branch that all contributors push to directly. This page walks through the full workflow from first-time setup to pushing changes safely.

---

## 1. Initial setup — cloning the repository

```bash
git clone https://github.com/eth-vaw-glaciology/GloGEM.git
cd GloGEM
cp config.pro.example config.pro   # create your personal config (git-ignored)
```

You only need to clone once. After that, use `git pull` to get new changes.

---

## 2. Before editing anything — always pull first

Before you start making changes, bring your local copy up to date with the remote:

```bash
git pull
```

This is the single most important habit to develop. If someone else pushed changes since your last pull, skipping this step is the most common cause of merge conflicts.

---

## 3. Making changes

Edit files normally. At any point you can check what has changed:

```bash
git status          # which files have been modified, added, or deleted
git diff            # see the exact line-level changes (unstaged)
git diff --staged   # see what is already staged for the next commit
```

---

## 4. Staging and committing

**Stage** the specific files you want to include in the next commit:

```bash
git add path/to/file.md          # stage one file
git add procedures/processing/   # stage a whole directory
```

Avoid `git add .` or `git add -A` unless you have reviewed every changed file with `git status` first — it is easy to accidentally commit temporary files or personal settings.

**Commit** with a short, descriptive message explaining *what changed and why*:

```bash
git commit -m "docs: add glacier retreat model equations to model description"
git commit -m "fix: move dircali assignment to after config.pro load"
```

Good commit messages make it much easier to understand the project history later.

---

## 5. Pushing — the safe workflow

Before pushing, always pull once more to catch any changes that landed since you started working:

```bash
git pull       # get latest remote changes
git push       # push your commits
```

The full recommended sequence for any editing session is:

```
git pull           ← start of session
[ edit files ]
git add <files>
git commit -m "..."
git pull           ← before pushing, in case someone else pushed in the meantime
git push           ← send your commits to the remote
```

If `git pull` at step 5 brings in no new changes, `git push` will succeed immediately. If it does bring in new changes, Git will attempt to merge them automatically. In most cases (changes to different files or different parts of the same file) this succeeds without any intervention and you can then `git push`.

---

## 6. Resolving merge conflicts

A conflict occurs when two contributors edited the same lines of the same file and Git cannot decide which version to keep. Git will tell you:

```
Auto-merging docs/source/model-description/mass-balance/index.md
CONFLICT (content): Merge conflict in docs/source/model-description/mass-balance/index.md
Automatic merge failed; fix conflicts and then commit the result.
```

### Step-by-step resolution

**1. See which files have conflicts:**
```bash
git status
```
Conflicted files are shown as `both modified`.

**2. Open each conflicted file.** Git marks the conflicting sections like this:

```
<<<<<<< HEAD
Your local version of the text.
=======
The incoming version from the remote.
>>>>>>> origin/main
```

**3. Edit the file** to produce the correct final version. Delete all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) and keep whichever content is correct — or combine both if both changes should be preserved.

**4. Stage the resolved file:**
```bash
git add docs/source/model-description/mass-balance/index.md
```

**5. Complete the merge commit:**
```bash
git commit   # Git pre-fills a merge commit message — just save and close
```

**6. Push:**
```bash
git push
```

---

## 7. Best practices to avoid conflicts

| Practice | Why it helps |
|----------|-------------|
| **Pull at the start of every session** | You start from the latest version, so your changes diverge from the remote as little as possible |
| **Push soon after committing** | Long-lived local commits increase the chance that someone else edits the same file in the meantime |
| **Make small, focused commits** | Smaller diffs are easier to merge and easier for others to review |
| **Communicate before editing shared files** | If two people are actively rewriting the same section of the documentation, coordinate via Slack or email to avoid overlapping edits |
| **Do not accumulate many local commits before pushing** | Each unpushed commit is a potential source of conflict |
| **Keep `config.pro` out of commits** | It is already in `.gitignore` — never force-add it |

---

## Quick reference

```bash
# Start of session
git pull

# Check state
git status
git diff

# Stage and commit
git add <file>
git commit -m "short description"

# Push safely
git pull
git push

# If conflicts appear after git pull
git status                  # find conflicted files
# edit and resolve each file
git add <resolved-file>
git commit
git push
```
