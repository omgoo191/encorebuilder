#ifndef FILEHANDLER_H
#define FILEHANDLER_H

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QCoreApplication>
#include <QDebug>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMetaType>
#include <QProcess>
#include <QByteArray>
class FileHandler : public QObject
{
Q_OBJECT

public:
	explicit FileHandler(QObject *parent = nullptr);

	Q_INVOKABLE QString getAppDirectory() const;

	/**
	 * @brief Save data to a JSON file
	 * @param filename The name of the file to save
	 * @param data The data to save (QVariantList, QVariantMap, or QString containing JSON)
	 * @return true if successful, false otherwise
	 */
	Q_INVOKABLE bool saveToFile(const QString &filename, const QVariant &data);

	/**
	 * @brief Load data from a JSON file
	 * @param filename The name of the file to load
	 * @return QVariant containing the loaded data (QVariantList or QVariantMap)
	 */
	Q_INVOKABLE QVariant loadFromFile(const QString &filename);

	Q_INVOKABLE void writeFile(const QString &path, const QString &content);
	Q_INVOKABLE QString cleanPath(const QString &path) const;
	static void registerType();

public slots:
	void runPythonScript(const QString &jsonFilePath, bool type);
signals:
	void pythonFinished(const QString &output);
	void pythonError(const QString &error);
	void pythonProcessResult(const QVariantMap &result);

private:
	bool ensureOutputDirectory() const;

	QVariant loadFromRelativePath(const QString &relativePath);

	bool saveToRelativePath(const QString &relativePath, const QVariant &data);

	QProcess *m_process;
	QByteArray m_stdoutBuffer;
	QByteArray m_stderrBuffer;
	QString m_currentExecutable;
	QString m_currentScript;
	QString m_currentInputFile;

};

#endif // FILEHANDLER_H
