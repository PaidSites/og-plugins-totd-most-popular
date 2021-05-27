def changes = ""
def continue_build = false

pipeline {
    agent any
    options {
        timeout(time: 15, unit: "MINUTES")
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '5'))
    }

    environment {
        CHANGED_FILES = """${sh(
            returnStdout: true,
            script: 'git diff --name-only \$(git rev-list --parents -n 1 \${GIT_COMMIT} | cut -d " " -f 2) \${GIT_COMMIT} | head -c 1000'
        )}
        """
    }

    stages {
        stage('Setup') {
            steps {
                sh 'cp /jd/configs/make_secrets .'
                sh 'source ./make_secrets'

                script {
                    changes = env.CHANGED_FILES.replace("\n", " ").trim()
                    echo "changes = ${changes}"

                    // assume requeue/rebuild when empty.
                    if (changes == "" || changes == null) {
                        changes = ""
                        continue_build = true
                    }

                    // if the changed files are build files or source files, build always.
                    if (changed_files.indexOf('Jenkinsfile', 0) > -1 ||
                        changed_files.indexOf('Makefile', 0) > -1 ||
                        changed_files.indexOf('sonar-project.properties', 0) > -1 ||
                        changed_files.indexOf('src/', 0) > -1
                        ) {
                        continue_build = true
                    }

                    echo "continue_build = ${continue_build}"

                    if (continue_build == true) {
                        echo 'This is a code push; continuing deployment...'
                    } else {
                        echo 'This is a non-code push; skipping deployment...'
                        currentBuild.result = 'NOT_BUILT'
                    }
                }

                sh 'printenv'
            }
        }
        stage('SonarQube Analysis') {
            environment {
                SCANNER_HOME = tool 'SonarQubeScanner'
            }
            steps {
                withSonarQubeEnv('og-sonarqube') {
                    sh "${SCANNER_HOME}/bin/sonar-scanner"
                }
            }
        }
	    stage("Quality Gate") {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    // Parameter indicates whether to set pipeline to UNSTABLE if Quality Gate fails
                    // true = set pipeline to UNSTABLE, false = don't
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('Test') {
            parallel {
                stage('Test (PASS)') {
                    when { expression { continue_build } }
                    steps {
                        echo 'Skipping tests for now.'
                        // sh "make test_pass_wp"
                    }
                }
                stage('Test (FAIL = PASS)') {
                    when { expression { continue_build } }
                    steps {
                        echo 'Skipping tests for now.'
                        // sh "make test_fail"
                    }
                }
            }
        }
        stage('Create Release') {
            when { expression { continue_build } }
            steps { sh 'make create_release' }
        }
        stage('End') { steps { echo 'Pipeline complete.' } }
    }
    post {
        cleanup {
            // Cleanup
            cleanWs()
            deleteDir()
        }
        success {
            // echo 'This will run only if successful'
            notifyBuild("SUCCESS")
        }
        failure {
            // echo 'This will run only if failed'
            // notifyBuild("FAILURE")
            // Cleanup
            cleanWs()
            deleteDir()
        }
        notBuilt {
            // echo 'This runs only when not built'
            notifyBuild("NOT_BUILT")
        }
        unstable {
            // echo 'This will run only if the run was marked as unstable'
            notifyBuild("UNSTABLE")
        }
        // changed {
        //     // echo 'This will run only if the state of the Pipeline has changed'
        //     // echo 'For example, if the Pipeline was previously failing but is now successful'
        // }
    }
}

def trimMEValues(String valueToTrim, String makeEnvValue) {
    if (valueToTrim == null || makeEnvValue == null) return ""
    return valueToTrim.replace(makeEnvValue, "").replace(" ", "").replace("=", "").trim()
}

def notifyBuild(String buildStatus = 'UNSTABLE') {
    // build status of null means successful
    buildStatus =  buildStatus ?: 'UNSTABLE'

    // Default values
    def colorName = 'RED'
    def colorCode = '#ff0202'
    def emoji = ':alarm:'
    def target_channel = '#jenkins'
    def giturl = "${env.GIT_URL}".replace(".git", "") << "/tree/${env.GIT_BRANCH}"
    def build_time = "${currentBuild.durationString}".replace(" and counting", "")
    def branch_name = "${env.BRANCH_NAME}"

    def repo_name = "${env.GIT_URL}".replace("https://github.com/PaidSites/", "").replace(".git", "")
    def sonar_url = "https://sonar.ocweb.tools/dashboard?id=PaidSites_${repo_name}"

    // Override default values based on build status.
    if (buildStatus == 'UNSTABLE') {
        colorName = 'YELLOW'
        colorCode = '#ffcc00'
        emoji = ':thunder-cloud-and-rain:'
    } else if (buildStatus == 'SUCCESS') {
        colorName = 'GREEN'
        colorCode = '#aaff0e'
        emoji = ':koolaid:'
    } else if (buildStatus == 'NOT_BUILT') {
        colorName = 'GREY'
        colorCode = '#bbbbbb'
        emoji = ':neutral_face:'
    } else {
        colorName = 'RED'
        colorCode = '#ff0202'
        emoji = ':alarm:'
        target_channel = '#jenkins, #dev-ops-team'
    }

    def subject = "${emoji}  [build ${env.BUILD_NUMBER}] *${buildStatus}*\n\n${repo_name}\n"
    def summary = "${subject} Git:\n${giturl}\nJenkins (Blue Ocean):\n${env.RUN_DISPLAY_URL}\nSonar:\n${sonar_url}\n\n>build time: ${build_time}"

    echo "slackSend:  subject = ${subject}"
    echo "slackSend:  summary = ${summary}"

    // Send notification
    slackSend (
        baseUrl: 'https://oxfordfinancialgroup.slack.com/services/hooks/jenkins-ci/',
        teamDomain: 'oxfordfinancialgroup',
        channel: target_channel,
        botUser: true,
        tokenCredentialId: 'creds_20191002T1500',
        color: colorCode,
        message: summary
    )
}