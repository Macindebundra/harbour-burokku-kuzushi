import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: gamePage
    allowedOrientations: Orientation.Landscape

    // ゲーム状態プロパティ
    property int score: 0
    property int blockRows: 5
    property int blockColumns: 8
    property real blockMargin: 5
    property bool gameOver: false
    property bool levelCleared: false
    property alias ballX: ball.x
    property alias ballY: ball.y
    property bool initialized: false
    property int countdown: 3
    property bool isCounting: false
    property bool gameStarted: false
    property bool initialScreen: true
    property bool showInstructions: true

    // メインゲーム画面
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: parent.height

        // プルダウンメニュー (最前面に表示)
        PullDownMenu {
            id: pullDownMenu
            z: 100  // 最高Z値で常に前面に

            MenuItem {
                text: initialScreen ? "Start Game" : "Restart Game"
                onClicked: {
                    if (initialScreen) {
                        initialScreen = false;
                        showInstructions = false;
                        startGame()
                    } else {
                        resetGame()
                    }
                }
            }
        }

        // ゲーム背景
        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Label {
            id: countdownText
            text: countdown > 0 ? countdown : "GO!"
            color: "white"
            font.pixelSize: Theme.fontSizeHuge
            anchors.centerIn: parent
            visible: isCounting
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 500} }
        }

        // ゲーム要素コンテナ
        Item {
            id: gameContent
            anchors.fill: parent

            /* ボール定義 */
            Rectangle {
                id: ball
                width: 20; height: 20
                radius: width / 2
                color: "white"
                visible: !initialScreen && !gameOver
                z: 2

                property real vx: 0  // X軸速度
                property real vy: 0  // Y軸速度

                Component.onCompleted: resetPosition()

                function resetPosition() {
                    x = gamePage.width / 2 - width / 2
                    y = gamePage.height / 3
                    vx = 8 * (Math.random() > 0.5 ? 1 : -1)
                    vy = 8
                    visible = true
                }
            }

            /* パドル定義 */
            Rectangle {
                id: paddle
                width: 200; height: 20
                color: "blue"
                z: 1

                function resetPosition() {
                    x = (parent.width - width) / 2
                    y = parent.height - 50
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: initialScreen ? null : paddle
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: gamePage.width - paddle.width
                }
            }

            /* ブロックエリア */
            Item {
                id: blockArea
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 10
                }
                height: 120
                z: 0

                property var blocks: []
                property real blockWidth: (width - (blockColumns-1)*blockMargin) / blockColumns
                property real blockHeight: 20

                Component.onCompleted: if (initialized) generateBlocks()

                // ブロック生成関数
                function generateBlocks() {
                    // 既存ブロック削除
                    for (var i = 0; i < blocks.length; i++) {
                        if (blocks[i]) blocks[i].destroy();
                    }

                    blocks = [];

                    // 新しいブロック生成
                    for (var row = 0; row < blockRows; row++) {
                        for (var col = 0; col < blockColumns; col++) {
                            var block = blockComponent.createObject(blockArea, {
                                x: col * (blockWidth + blockMargin),
                                y: row * (blockHeight + blockMargin),
                                width: blockWidth,
                                height: blockHeight,
                                color: Qt.rgba(row/blockRows, 0.5, 1-row/blockRows, 1),
                                alive: true,
                                visible: initialScreen || !gameOver
                            });
                            blocks.push(block);
                        }
                    }
                }
            }

            // ブロックコンポーネント定義
            Component {
                id: blockComponent
                Rectangle {
                    property bool alive: true
                    visible: alive && (initialScreen || !gameOver)
                    radius: 3
                    border.color: "white"
                    border.width: 1

                    Component.onCompleted: alive = true
                }
            }

            // 画面サイズ変更時の再配置
            Connections {
                target: gamePage
                onWidthChanged: blockArea.generateBlocks()
            }

            // ゲームメインループ
            Timer {
                id: gameLoop
                interval: 16  // ~60fps
                running: false
                repeat: true

                onTriggered: {
                    if (gameOver || !gameStarted) return;

                    // ボール移動
                    ball.x += ball.vx;
                    ball.y += ball.vy;

                    // パドル衝突判定
                    var paddleHit = false;
                    if (ball.y + ball.height >= paddle.y &&
                        ball.y <= paddle.y + paddle.height &&
                        ball.x + ball.width >= paddle.x &&
                        ball.x <= paddle.x + paddle.width) {

                        var hitPos = (ball.x + ball.width/2 - paddle.x) / paddle.width;
                        ball.vx = (hitPos - 0.5) * 10;
                        ball.vy = -Math.abs(ball.vy);  // 上向きに反射

                        var speed = Math.sqrt(ball.vx*ball.vx + ball.vy*ball.vy);
                        var targetSpeed = 8;
                        ball.vx = (ball.vx / speed) * targetSpeed;
                        ball.vy = (ball.vy / speed) * targetSpeed;

                        paddleHit = true;
                    }

                    // ブロック衝突判定
                    var allCleared = true;
                    for (var i = 0; i < blockArea.blocks.length; i++) {
                        var block = blockArea.blocks[i];
                        if (block.alive && checkCollision(ball, block)) {
                            handleBlockCollision(block);
                            if (block.alive) allCleared = false;
                        } else if (block.alive) {
                            allCleared = false;
                        }
                    }

                    // クリア/ゲームオーバー判定
                    if (allCleared) endGame(true);
                    else if (ball.y >= parent.height) endGame(false);
                    else if (ball.x <= 0 || ball.x >= parent.width - ball.width) ball.vx *= -1;
                    else if (ball.y <= 0) ball.vy *= -1;
                }

                // 衝突判定関数
                function checkCollision(obj1, obj2) {
                    return obj1.x + obj1.width > obj2.x &&
                           obj1.x < obj2.x + obj2.width &&
                           obj1.y + obj1.height > obj2.y &&
                           obj1.y < obj2.y + obj2.height;
                }

                // ブロック衝突処理
                function handleBlockCollision(block) {
                    block.alive = false;
                    block.visible = false;
                    score += 10;

                    // 衝突面に応じた反射
                    var collision = getCollisionSide(ball, block);
                    if (collision === "top" || collision === "bottom") {
                        ball.vy *= -1;
                    } else {
                        ball.vx *= -1;
                    }
                }

                // 衝突面判定
                function getCollisionSide(ball, block) {
                    var ballCenter = Qt.point(ball.x + ball.width/2, ball.y + ball.height/2);
                    var blockCenter = Qt.point(block.x + block.width/2, block.y + block.height/2);

                    var dx = ballCenter.x - blockCenter.x;
                    var dy = ballCenter.y - blockCenter.y;
                    var width = (ball.width + block.width)/2;
                    var height = (ball.height + block.height)/2;

                    if (Math.abs(dx) <= width && Math.abs(dy) <= height) {
                        return (Math.abs(dx/width) > Math.abs(dy/height))
                            ? (dx > 0 ? "right" : "left")
                            : (dy > 0 ? "bottom" : "top");
                    }
                    return "none";
                }
            }
        }

        // スコア表示
        Label {
            text: "Score: " + score
            color: "white"
            font.pixelSize: Theme.fontSizeLarge
            anchors.top: parent.top
            anchors.topMargin: Theme.paddingLarge
            anchors.horizontalCenter: parent.horizontalCenter
            z: 3
        }
    }

    function randomAngle() {
        var ang = 0;
        ang = Math.random() * (Math.PI / 9) * 5 + (Math.PI / 9) * 2;
        if (ang < (Math.PI * 5) / 9 && ang > (Math.PI * 4) / 9) {
            return randomAngle();
        }
        return ang;
    }

    function setBallVelocity() {
        var angle = randomAngle();
        var speed = 8;
        ball.vx = Math.cos(angle) * speed;
        ball.vy = Math.sin(angle) * speed;
    }

    onStatusChanged: {
        if (status === PageStatus.Active && !initialized) {
            initializeGame()
        }
    }

    function initializeGame() {
        if (initialized) return
        initialized = true

        paddle.x = (parent.width - paddle.width) / 2
        paddle.y = parent.height - 150

        ball.x = parent.width / 2 - ball.width / 2
        ball.y = parent.height / 3

        resetGame()
    }

    Label {
        id: instructionText
        text: "Swipe down to start Game"
        color: "white"
        font.pixelSize: Theme.fontSizeHuge
        font.bold: true
        anchors.centerIn: parent
        visible: initialScreen && showInstructions
        z: 10
    }

    // ゲームオーバーメッセージ (z-index: 6)
    Label {
        id: gameOverText
        text: levelCleared ? "Level Clear!" : "Game Over"
        color: "white"
        font.pixelSize: Theme.fontSizeHuge
        font.bold: true
        anchors.centerIn: parent
        visible: false
        z: 6
    }

    function startCountdown() {
        gameLoop.running = false;
        isCounting = true;
        countdown = 3;
        countdownTimer.start();
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            countdown--;
            if (countdown <= 0) {
                stop();
                isCounting = false;
                gameStarted = true;
                gameLoop.running = true;
            }
        }
    }

    function startGame() {
        ball.resetPosition()
        ball.visible = true;

        for(var i = 0; i < blockArea.blocks.length; i++) {
            blockArea.blocks[i].alive = true
            blockArea.blocks[i].visible = true
        }

        countdownText.visible = true
        countdownText.text = "3"
        countdownTimer.start()
    }

    // ゲームリセット関数
    function resetGame() {
        // 状態リセット
        gameOverText.visible = false;
        gameOver = false;
        levelCleared = false;
        isCounting = false;
        countdownText.visible = false;
        score = 0;

        gameLoop.running = false;

        ball.resetPosition()
        ball.visible = !initialScreen;
        paddle.resetPosition()

        // ブロック再生成
        blockArea.generateBlocks();

        startTimer.start()

        if (!initialScreen) {
            setBallVelocity();
            startCountdown();
        }
    }

    Timer {
        id: startTimer
        interval: 100
        onTriggered: {
            gameLoop.running = true
        }
    }

    // ゲーム終了処理
    function endGame(cleared) {
        gameOver = true;
        gameStarted = false;
        levelCleared = cleared;
        gameOverText.text = cleared ? "Level Clear!" : "Game Over";
        gameOverText.visible = true;
        gameLoop.running = false;
    }
}
