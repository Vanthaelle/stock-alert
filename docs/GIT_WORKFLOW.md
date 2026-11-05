# Git workflow

Create commits as you actually complete and verify each phase. Do not backdate commits.

```bash
git init
git branch -M main
git add app/config.php app/db.php app/bootstrap.php app/auth.php app/csrf.php app/response.php app/validators.php .htaccess .gitignore
git commit -m "chore(setup): add PHP bootstrap and configuration"

git switch -c feat/database
git add database/stock_alert.sql
git commit -m "feat(database): add inventory schema and seed data"
git switch main
git merge --no-ff feat/database -m "merge: database foundation"

git switch -c feat/auth-shell
git add setup.php login.php logout.php index.php pages partials assets/css assets/js
git commit -m "feat(auth): add account setup and dashboard shell"
git switch main && git merge --no-ff feat/auth-shell -m "merge: authentication and UI shell"

git switch -c feat/inventory-transfers
git add app/services api cron tests
 git commit -m "feat(inventory): add ledger, alerts and transfers"
git switch main && git merge --no-ff feat/inventory-transfers -m "merge: inventory workflows"

git add README.md docs/GIT_WORKFLOW.md docs/DEPLOYMENT.md
git commit -m "docs: add setup and deployment guides"
```

Suggested phase grouping: P0 config/bootstrap/security headers; P1 SQL; P2 auth and shell; P3 master data; P4 batch/movements; P5 transfers; P6 dashboard/alerts; P7 tests/docs. Stage only files you have personally verified for that phase.
