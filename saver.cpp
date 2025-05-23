#include "saver.h"
#include <QQmlEngine>
#include <QStandardPaths>
#include <QDir>

FileHandler::FileHandler(QObject *parent) : QObject(parent)
{
	m_process = new QProcess(this);
	connect(m_process, &QProcess::readyReadStandardOutput, [this]() {
		emit pythonFinished(QString::fromLocal8Bit(m_process->readAllStandardOutput()));
	});
	connect(m_process, &QProcess::errorOccurred, [this](QProcess::ProcessError error) {
		emit pythonError(QString("Error: %1").arg(error));
	});
}
QString FileHandler::getAppDirectory() const {
	QDir projectDir(QCoreApplication::applicationDirPath());
	projectDir.cdUp();
	return projectDir.absolutePath();
}

QString FileHandler::cleanPath(const QString &path) const {
	QString cleaned = path;
	cleaned.replace("file://", "");

	if (cleaned.startsWith("/") && cleaned	[2] == ':') {
		cleaned = cleaned.mid(1);
	}

	return cleaned;
}

bool FileHandler::saveToFile(const QString &filePath, const QVariant &data) {
	QString absolutePath = cleanPath(filePath);

	QFile file(absolutePath);
	if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
		qWarning() << "Cannot open file for writing:" << file.fileName();
		return false;
	}

	QJsonDocument doc;
	QMetaType dataType(data.metaType());

	if (dataType == QMetaType::fromType<QVariantList>() ||
		dataType == QMetaType::fromType<QStringList>()) {
		doc = QJsonDocument(QJsonArray::fromVariantList(data.toList()));
	}
	else if (dataType == QMetaType::fromType<QVariantMap>()) {
		doc = QJsonDocument(QJsonObject::fromVariantMap(data.toMap()));
	}
	else if (data.canConvert(QMetaType(QMetaType::QString))) {
		QJsonParseError error;
		doc = QJsonDocument::fromJson(data.toString().toUtf8(), &error);
		if (error.error != QJsonParseError::NoError) {
			qWarning() << "Invalid JSON string:" << error.errorString();
			return false;
		}
	}

	if (doc.isNull()) {
		qWarning() << "Failed to create JSON document from data";
		return false;
	}

	qint64 bytesWritten = file.write(doc.toJson(QJsonDocument::Indented));
	file.close();
	return bytesWritten > 0;
}

QVariant FileHandler::loadFromFile(const QString &filePath) {
	QString absolutePath = cleanPath(filePath);

	QFile file(absolutePath);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
		qWarning() << "Cannot open file for reading:" << file.fileName();
		return QVariant();
	}

	QByteArray data = file.readAll();
	file.close();

	QJsonParseError error;
	QJsonDocument doc = QJsonDocument::fromJson(data, &error);
	if (error.error != QJsonParseError::NoError) {
		qWarning() << "JSON parse error:" << error.errorString();
		return QVariant();
	}

	if (doc.isArray()) {
		return doc.array().toVariantList();
	}
	else if (doc.isObject()) {
		return doc.object().toVariantMap();
	}

	return QVariant();
}

void FileHandler::registerType() {
	qmlRegisterType<FileHandler>("FileIO", 1, 0, "FileHandler");
}

QVariant FileHandler::loadFromRelativePath(const QString &relativePath) {
	QString fullPath = getAppDirectory() + "/" + relativePath;
	return loadFromFile(fullPath);
}

bool FileHandler::saveToRelativePath(const QString &relativePath, const QVariant &data) {
	QString fullPath = getAppDirectory() + "/" + relativePath;
	return saveToFile(fullPath, data);
}

void FileHandler::runPythonScript(const QString &jsonFilePath, bool type)
{
	QFileInfo fileInfo(jsonFilePath);
	if (!fileInfo.exists()) {
		emit pythonError("? ?? ?? ¡£©?¡¢÷£?¢: " + jsonFilePath);
		return;
	}

	QString basePath = QCoreApplication::applicationDirPath();
	QDir path(basePath);
	path.cdUp();
	QString pythonExec = QCoreApplication::applicationDirPath() + (type ? "/Generator.exe" : "/exel_generator.exe");
	QString scriptPath = type ? path.filePath("Generator.py") : path.filePath("exel_generator.py");

	if (!QFile::exists(pythonExec)) {
		emit pythonError("Python ?? ? ?ý??: " + pythonExec);
		return;
	}
	if (!QFile::exists(scriptPath)) {
		emit pythonError("?ò ðô¢ ?? ? ?ý??: " + scriptPath);
		return;
	}

	if (!m_process) {
		m_process = new QProcess(this);
	}
	connect(m_process, &QProcess::readyReadStandardError, [=]() {
		qDebug() << "stderr:" << m_process->readAllStandardError();
	});
	connect(m_process, &QProcess::readyReadStandardOutput, [=]() {
		qDebug() << "stdout:" << m_process->readAllStandardOutput();
	});
	m_process->setWorkingDirectory(path.absolutePath());
	m_process->start(pythonExec, QStringList() << jsonFilePath);
}
