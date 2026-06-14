# ShellScanner

A Bash-based security auditing tool designed to scan repositories for potentially dangerous scripts, insecure permissions, exposed secrets, suspicious binaries, and malformed environment files.

## Project Overview

The project simulates a real-world DevOps incident where a developer pushes unreviewed code into a repository. The objective is to automatically inspect the repository, identify security risks, sanitize configuration files, maintain audit logs, and assist in tracking the source of suspicious files.

The project was implemented entirely using Bash scripting and Linux utilities.

---

# Features

## Threat Detection

The scanner recursively inspects all shell scripts and detects:

* Destructive commands

  * `rm -rf /`
  * `mkfs`
  * `shutdown`
  * `reboot`

* Suspicious downloads

  * `curl ... | bash`
  * `curl ... | sh`
  * `wget ... | bash`
  * `wget ... | sh`

* Reverse shell patterns

  * `/dev/tcp/`
  * `bash -i`
  * `nc -e`

* Insecure permissions

  * World writable scripts (`777`, `o+w`)

---

## Interactive Permission Fixing

When an insecure permission is detected, the user is prompted to remove world-write access.

Example:

```text
[WARN] scripts/deploy.sh _ Reason: World writable permission (777)

Fix permissions for scripts/deploy.sh? (yes/no):
```

---

## Environment File Sanitization

The scanner recursively searches for `.env` files and creates sanitized copies.

Valid examples:

```env
API_KEY=spider26
PORT=3000
_DEBUG=false
```

Rejected examples:

```env
KEY = value
SERVER-NAME=x
USER="admin"
PASSWORD=secret
TOKEN=abc
export PATH=$PATH:/tmp
```

Output:

```text
.env.sanitized
```

---

## Logging and Auditing

Every action is recorded in:

```text
logs/vault_sweep.log
```

Example:

```text
[2026-06-14 10:15:00] [WARN] scripts/delete.sh contains dangerous command

[2026-06-14 10:15:05] [FIX] scripts/delete.sh removed world write permission
```

---

## Hardcoded Secret Detection

The scanner checks JavaScript and Python files for:

```js
const apiKey = "secret";
```

```python
token = "abcdef";
```

and reports them with line numbers.

---

## High Entropy / Base64 Detection

Long encoded strings are flagged because they may contain:

* Encoded payloads
* Embedded malware
* Hidden credentials

Example:

```python
payload = "VGhpcyBpcyBhIHN1c3BpY2lvdXMgc3RyaW5n"
```

---

## Binary File Detection

Unexpected executables found inside repositories are flagged.

Example:

```text
test_data/dangerous/malware
```

---

## Git Integration

The scanner uses Git metadata to identify who last modified suspicious files.

Information recorded:

* Author
* Commit hash
* Commit date

This helps trace the origin of potentially dangerous code.

---

## Watchdog Monitoring

A separate monitoring script periodically runs the scanner and generates alerts whenever suspicious activity is detected.

---

# Project Structure

```text
ShellScanner/
│
├── vault_sweep.sh
├── watchdog.sh
│
├── logs/
│   └── vault_sweep.log
│
├── test_data/
│   ├── dangerous/
│   └── safe/
│
└── README.md
```

---

# Development Journey

This project was built incrementally rather than implementing everything at once.

## Stage 1 – Understanding Bash Scripting

Initially, the focus was on understanding:

* Shell scripts
* File traversal
* Linux permissions
* Command-line utilities

Before implementing detection logic, small experiments were performed using:

```bash
find
grep
chmod
stat
```

to understand how repository scanning works.

---

## Stage 2 – Recursive Script Scanning

The first working version simply located all shell scripts:

```bash
find target_directory -type f -name "*.sh"
```

This established the base scanning mechanism used throughout the project.

### Challenge Faced

At this stage there was no filtering or detection logic. The main challenge was understanding recursive file traversal and ensuring files in nested directories were included.

---

## Stage 3 – Threat Detection

Pattern matching was added using:

```bash
grep -E
```

to identify:

* Destructive commands
* Suspicious downloads
* Reverse shell patterns

### Challenge Faced

Creating regular expressions that correctly matched dangerous commands without generating too many false positives.

Understanding escaped characters such as:

```bash
\|
```

inside regex patterns required additional testing.

---

## Stage 4 – Permission Auditing

World-writable files were identified and users were given the option to fix them interactively.

### Challenge Faced

A significant issue occurred when using:

```bash
find ... | while read file
```

combined with:

```bash
read ans
```

for user input.

The script entered unexpected behaviour because both commands attempted to read from the same input stream.

### Solution

User input was redirected from:

```bash
/dev/tty
```

allowing terminal interaction without interfering with the scanning pipeline.

This was one of the most important debugging lessons learned during the project.

---

## Stage 5 – Logging System

A logging system was introduced to maintain an audit trail.

### Challenge Faced

Ensuring that every warning, fix, and informational message was recorded consistently while also keeping terminal output readable.

---

## Stage 6 – Environment Sanitization

The next milestone was validating environment files.

### Challenge Faced

Designing a regular expression that accepted:

```env
API_KEY=value
```

while rejecting:

```env
KEY = value
SERVER-NAME=x
USER="admin"
```

required careful testing of Bash regex behaviour.

Another challenge was distinguishing valid configuration variables from sensitive secrets.

---

## Stage 7 – Secret Detection

JavaScript and Python files were scanned for hardcoded credentials.

### Challenge Faced

Secret formats vary significantly across programming languages.

The solution focused on detecting common identifiers such as:

```text
apikey
token
secret
password
```

rather than attempting to detect every possible credential format.

---

## Stage 8 – High Entropy String Detection

The scanner was extended to identify long Base64-like strings.

### Challenge Faced

Balancing sensitivity and false positives.

Short strings generated too many unnecessary warnings, so a minimum length threshold was introduced.

---

## Stage 9 – Binary Detection

Unexpected executables were flagged.

### Challenge Faced

The Docker environment initially lacked the `file` utility.

This required adapting the approach and understanding alternative methods for identifying executable files.

---

## Stage 10 – Git Integration

Git metadata was added to improve auditing.

### Challenge Faced

Understanding how to retrieve file-specific commit information rather than repository-wide commit information.

This required experimenting with:

```bash
git log
git blame
```

and understanding how Git tracks file history.

---

## Stage 11 – GitHub Deployment

The repository was pushed to GitHub.

### Challenges Faced

Several Git-related issues were encountered:

* Incorrect remote URL syntax
* Personal Access Token authentication
* Permission errors (403)
* Remote branch conflicts
* Non-fast-forward push rejections

Resolving these issues provided practical experience with real Git workflows.

---

# Technologies Used

* Bash
* Linux
* Git
* GitHub
* Docker
* grep
* find
* stat
* chmod
* cron

---

# Future Improvements

Potential improvements include:

* Entropy scoring instead of simple regex detection
* Email alerts
* JSON log output
* CI/CD integration
* GitHub Actions support
* Severity-based threat classification

---

# Conclusion

This project provided hands-on experience with Linux security auditing, Bash scripting, repository analysis, Git workflows, and DevOps automation. The implementation was developed incrementally, with each stage introducing new functionality while also exposing practical debugging and troubleshooting challenges commonly encountered in real-world environments.
