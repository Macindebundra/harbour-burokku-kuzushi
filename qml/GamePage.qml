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

    onStatusChanged: {
        if (status === PageStatus.Active && !initialized) {
            initializeGame()
        }
    }

    function initializeGame() {
        if (initialized) return
        initialized = true

        paddle.x = (parent.width - paddle.width) / 2
        paddle.y = parent.height - 50

        ball.x = parent.width / 2 - ball.width / 2
        ball.y = parent.height / 3

        resetGame()
    }

    // メインゲーム画面
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: parent.height

        // プルダウンメニュー (最前面に表示)
        PullDownMenu {
            id: pullDownMenu
            z: 100  // 最高Z値で常に前面に

            MenuItem {
                text: "Restart Game"
                onClicked: resetGame()
            }
        }

        // ゲーム背景
        Rectangle {
            anchors.fill: parent
            color: "black"
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
                visible: false
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
                    drag.target: paddle
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
                                color: Qt.rgba(row/blockRows, 0.5, 1-row/blockRows, 1)
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
                    visible: alive
                    radius: 3
                    border.color: "white"
                    border.width: 1
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
                running: true
                repeat: true

                onTriggered: {
                    if (gameOver) return;

                    // ボール移動
                    ball.x += ball.vx;
                    ball.y += ball.vy;

                    // パドル衝突判定
                    if (ball.y + ball.height >= paddle.y &&
                        ball.y <= paddle.y + paddle.height &&
                        ball.x + ball.width >= paddle.x &&
                        ball.x <= paddle.x + paddle.width) {
                        ball.vy = -Math.abs(ball.vy);  // 上向きに反射
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

    // ゲームリセット関数
    function resetGame() {
        // 状態リセット
        gameOverText.visible = false;
        gameOver = false;
        levelCleared = false;
        score = 0;

        gameLoop.running = false;

        ball.resetPosition()
        paddle.resetPosition()

        // ブロック再生成
        blockArea.generateBlocks();

        startTimer.start()
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
        levelCleared = cleared;
        gameOverText.text = cleared ? "Level Clear!" : "Game Over";
        gameOverText.visible = true;
        gameLoop.running = false;
    }
}
