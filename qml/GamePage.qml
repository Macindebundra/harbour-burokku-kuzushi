import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: gamePage
    allowedOrientations: Orientation.Landscape

    property int score: 0  // スコア変数を追加
    property int blockRows: 5
    property int blockColumns: 8
    property real blockMergin: 2

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: ball
            width: 20; height: 20
            radius: width / 2
            color: "white"
            x: parent.width / 2
            y: parent.height / 2

            property real vx: 5  // dx → vx に統一
            property real vy: 5  // dy → vy に統一
        }

        Rectangle {
            id: paddle
            width: 120; height: 20
            color: "blue"
            y: parent.height - 50
            x: (parent.width - width) / 2

            MouseArea {
                anchors.fill: parent
                drag.target: paddle
                drag.axis: Drag.XAxis
                drag.minimumX: 0
                drag.maximumX: gamePage.width - paddle.width
            }
        }

        Item {
            id: blockArea
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
            }
            height: 120

            property var blocks: []
            property real blockWidth: (width - (blockColumns-1)*blockMergin) / blockColumns
            property real blockHeight: 20

            Component.onCompleted: generateBlocks()

            function generateBlocks() {
                for (var i = 0; i < blocks.length; i++) {
                    if (blocks[i]) blocks[i].destroy()
                }
                blocks = []

                for (var row = 0; row < blockRows; row++) {
                    for (var col = 0; col < blockColumns; col++) {
                        // 文字列連結方式に変更（テンプレートリテラルはSailfish QMLで不安定）
                        var block =
                                blockComponent.createObject(blockArea, {
                                   x: col * (blockWidth + blockMergin),
                                   y: row * (blockHeight + blockMergin),
                                   width: blockWidth,
                                   height: blockHeight,
                                   color: Qt.rgba(row/blockRows, 0.5, 1 - row/blockRows,1)
                               })

                            //'blockComponent.createObject(blockArea, {' +
                            //'   x: col * (blockWidth + blockMergin),' +
                            //'   y: row * (blockHeight + blockMergin),' +
                            //'   width: blockwidth,' +
                            //'   height: blockHeight,' +
                            //'   color: Qt.raba(row/blockRows, 0.5, 1 - row/blockRows,1)' +
                            //'})';
                        blocks.push(block)
                    }
                }
            }
        }

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

        Connections{
            target: gamePage
            onWidthChanged: blockArea.generateBlocks()
        }

        Timer {
            id: gameLoop
            interval: 16
            running: true
            repeat: true
            onTriggered: {
                // ボール移動
                ball.x += ball.vx;
                ball.y += ball.vy;

                // パドル衝突判定
                if (ball.y + ball.height >= paddle.y &&
                    ball.x + ball.width >= paddle.x &&
                    ball.x <= paddle.x + paddle.width) {
                    ball.vy = -Math.abs(ball.vy);  // 常に上向きに反射
                }

                // 精密な衝突判定関数
                    function checkCollision(obj1, obj2) {
                        return obj1.x + obj1.width > obj2.x &&
                               obj1.x < obj2.x + obj2.width &&
                               obj1.y + obj1.height > obj2.y &&
                               obj1.y < obj2.y + obj2.height;
                    }

                    // 衝突面を判定する関数
                    function getCollisionSide(ball, block) {
                        var ballCenterX = ball.x + ball.width/2;
                        var ballCenterY = ball.y + ball.height/2;
                        var blockCenterX = block.x + block.width/2;
                        var blockCenterY = block.y + block.height/2;

                        var dx = ballCenterX - blockCenterX;
                        var dy = ballCenterY - blockCenterY;
                        var width = (ball.width + block.width)/2;
                        var height = (ball.height + block.height)/2;
                        var crossWidth = width * dy;
                        var crossHeight = height * dx;

                        if (Math.abs(dx) <= width && Math.abs(dy) <= height) {
                            if (crossWidth > crossHeight) {
                                return (crossWidth > -crossHeight) ? "bottom" : "left";
                            } else {
                                return (crossWidth > -crossHeight) ? "right" : "top";
                            }
                        }
                        return "none";
                    }

                // ブロック衝突判定
                for (var i = 0; i < blockArea.blocks.length; i++) {
                     var block = blockArea.blocks[i];
                     if (block.alive && checkCollision(ball, block)) {
                         block.alive = false;
                         block.visible = false;
                         score += 10;

                         // 衝突面に応じた反射処理
                         var collision = getCollisionSide(ball, block);
                         if (collision === "top" || collision === "bottom") {
                             ball.vy *= -1; // 上下からの衝突はY方向反転
                         } else {
                             ball.vx *= -1; // 左右からの衝突はX方向反転
                         }
                     }
                }



                // 壁衝突判定
                if (ball.x <= 0 || ball.x >= parent.width - ball.width) ball.vx *= -1;
                if (ball.y <= 0) ball.vy *= -1;

                // ゲームオーバー
                if (ball.y >= parent.height) {
                    gameLoop.running = false;
                    console.log("Game Over");
                }
            }
        }
    }

    Label {
        text: "Score: " + score  // スコア表示を更新
        color: "white"
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
