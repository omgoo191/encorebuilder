#include "saver.h"
#include <QQmlEngine>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>

FileHandler::FileHandler(QObject *parent) : QObject(parent)
{
	m_process = new QProcess(this);
	connect(m_process, &QProcess::readyReadStandardOutput, this, [this]() {
		m_stdoutBuffer.append(m_process->readAllStandardOutput());
		emit pythonFinished(QString::fromUtf8(m_stdoutBuffer));
	});
	connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
		m_stderrBuffer.append(m_process->readAllStandardError());
	});
	connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
		const QString errorText = QString::fromUtf8(m_stderrBuffer);
		QVariantMap result{
			{QStringLiteral("status"), QStringLiteral("process_error")},
			{QStringLiteral("processError"), static_cast<int>(error)},
			{QStringLiteral("executable"), m_currentExecutable},
			{QStringLiteral("script"), m_currentScript},
			{QStringLiteral("inputFile"), m_currentInputFile},
			{QStringLiteral("stdout"), QString::fromUtf8(m_stdoutBuffer)},
			{QStringLiteral("stderr"), errorText}
		};
		emit pythonProcessResult(result);
		emit pythonError(QStringLiteral("Ошибка запуска процесса / Process launch error: %1").arg(errorText));
	});
	connect(m_process,
			QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
			this,
			[this](int exitCode, QProcess::ExitStatus exitStatus) {
				const QString stdoutText = QString::fromUtf8(m_stdoutBuffer);
				const QString stderrText = QString::fromUtf8(m_stderrBuffer);
				const bool success = (exitStatus == QProcess::NormalExit && exitCode == 0);

				QVariantMap result{
					{QStringLiteral("status"), success ? QStringLiteral("success") : QStringLiteral("failed")},
					{QStringLiteral("exitCode"), exitCode},
					{QStringLiteral("exitStatus"), exitStatus == QProcess::NormalExit ? QStringLiteral("normal") : QStringLiteral("crash")},
					{QStringLiteral("executable"), m_currentExecutable},
					{QStringLiteral("script"), m_currentScript},
					{QStringLiteral("inputFile"), m_currentInputFile},
					{QStringLiteral("stdout"), stdoutText},
					{QStringLiteral("stderr"), stderrText}
				};

				emit pythonProcessResult(result);
				if (success) {
					emit pythonFinished(stdoutText);
				} else {
					emit pythonError(QStringLiteral("Скрипт завершился с ошибкой / Script failed (exit code %1). stderr: %2")
									.arg(exitCode)
									.arg(stderrText));
				}
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

	if (cleaned.startsWith("/") && cleaned[2] == ':') {
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
		emit pythonError(QStringLiteral("Файл JSON не найден / JSON file not found: %1").arg(jsonFilePath));
		return;
	}

	QString basePath = QCoreApplication::applicationDirPath();
	QDir path(basePath);
	path.cdUp();
	QString pythonExec = QCoreApplication::applicationDirPath() + (type ? "/Generator.exe" : "/excel_generator.exe");
	QString scriptPath = type ? path.filePath("Generator.py") : path.filePath("excel_generator.py");

	if (!QFile::exists(pythonExec)) {
		emit pythonError(QStringLiteral("Исполняемый файл не найден / Executable not found: %1").arg(pythonExec));
		return;
	}
	if (!QFile::exists(scriptPath)) {
		emit pythonError(QStringLiteral("Скрипт не найден / Script not found: %1").arg(scriptPath));
		return;
	}

	if (m_process->state() != QProcess::NotRunning) {
		emit pythonError(QStringLiteral("Предыдущий процесс ещё выполняется / Previous process is still running"));
		return;
	}

	m_stdoutBuffer.clear();
	m_stderrBuffer.clear();
	m_currentExecutable = pythonExec;
	m_currentScript = scriptPath;
	m_currentInputFile = jsonFilePath;
	m_process->setWorkingDirectory(path.absolutePath());
	m_process->setProgram(pythonExec);
	m_process->setArguments(QStringList() << jsonFilePath);
	m_process->start();
}

void FileHandler::writeFile(const QString &path, const QString &content)
{
	QFile file(path);
	if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
		file.write(content.toUtf8());
		file.close();
	} else {
		emit pythonError(QStringLiteral("Ошибка при сохранении файла / Failed to save file: %1").arg(path));
	}
}
