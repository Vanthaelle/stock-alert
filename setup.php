<?php
declare(strict_types=1);

require __DIR__ . '/app/bootstrap.php';

$error = '';
$setupComplete = (int) db()->query(
    "SELECT COUNT(*) FROM users WHERE role = 'admin'"
)->fetchColumn() > 0;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hash_equals($_SESSION['csrf'] ?? '', (string) ($_POST['_csrf'] ?? ''))) {
        http_response_code(403);
        exit('Invalid request token. Refresh and retry.');
    }

    $lockAcquired = false;
    $created = false;

    try {
        $lockAcquired = (int) db()->query(
            "SELECT GET_LOCK('stock_alert_admin_setup', 10)"
        )->fetchColumn() === 1;

        if (!$lockAcquired) {
            throw new RuntimeException('Setup is busy. Please retry.');
        }

        $adminCount = (int) db()->query(
            "SELECT COUNT(*) FROM users WHERE role = 'admin'"
        )->fetchColumn();

        if ($adminCount > 0) {
            $setupComplete = true;
            $error = 'Administrator setup has already been completed.';
        } else {
            $name = trim((string) ($_POST['name'] ?? ''));
            $email = filter_var(
                trim((string) ($_POST['email'] ?? '')),
                FILTER_VALIDATE_EMAIL
            );
            $password = (string) ($_POST['password'] ?? '');

            if ($name === '' || strlen($name) > 120 || !$email || strlen($password) < 12) {
                $error = 'Enter a valid name, email, and password of at least 12 characters.';
            } else {
                $stmt = db()->prepare(
                    "INSERT INTO users (name, email, password_hash, role)
                     VALUES (?, ?, ?, 'admin')"
                );

                $stmt->execute([
                    $name,
                    $email,
                    password_hash($password, PASSWORD_DEFAULT)
                ]);

                $created = true;
            }
        }
    } catch (PDOException $e) {
        error_log('Admin setup database error: ' . $e->getMessage());
        $error = 'Unable to create the administrator. Check the details and try again.';
    } catch (RuntimeException $e) {
        $error = $e->getMessage();
    } finally {
        if ($lockAcquired) {
            db()->query("SELECT RELEASE_LOCK('stock_alert_admin_setup')");
        }
    }

    if ($created) {
        header('Location: index.php?created=1');
        exit;
    }
}

?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Create Admin · Stock-Alert</title>
    <link rel="stylesheet" href="assets/css/app.css">
</head>
<body class="auth">
    <form class="auth-card" method="post">
        <input type="hidden" name="_csrf" value="<?= e(csrf_token()) ?>">

        <div class="brand-mark">S</div>
        <h1>Create administrator</h1>
        <p>First-run setup for your Stock-Alert system.</p>

        <?php if ($setupComplete): ?>
            <p class="error">Administrator setup is already complete.</p>
            <a class="btn primary" href="index.php">Go to login</a>
        <?php else: ?>
            <?php if ($error !== ''): ?>
                <p class="error"><?= e($error) ?></p>
            <?php endif; ?>

            <label>
                Full name
                <input name="name" required maxlength="120"
                       value="<?= e($_POST['name'] ?? '') ?>">
            </label>

            <label>
                Email
                <input type="email" name="email" required
                       value="<?= e($_POST['email'] ?? '') ?>">
            </label>

            <label>
                Password
                <input type="password" name="password"
                       minlength="12" required>
            </label>

            <button class="btn primary" type="submit">Create account</button>
        <?php endif; ?>
    </form>
</body>
</html>
