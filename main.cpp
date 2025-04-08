#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "saver.h"
#include "QQmlContext"
#include "stdlib.h"
#include <iostream>
#include "AppController.h"
int main(int argc, char *argv[])
{
	qputenv("QML_XHR_ALLOW_FILE_WRITE", "1");
	qputenv("QML_XHR_ALLOW_FILE_READ", "1");

    QGuiApplication app(argc, argv);
	FileHandler::registerType();
	AppController controller;
	QQmlApplicationEngine engine;
//		engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");


	engine.rootContext()->setContextProperty("fileHandler", new FileHandler());
	engine.rootContext()->setContextProperty("appController", &controller);
    const QUrl url(QStringLiteral("qrc:/Generator/Main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
	QObject::connect(&engine, &QQmlApplicationEngine::quit, &app, &QCoreApplication::quit);
    engine.load(url);

  	return app.exec();
}
