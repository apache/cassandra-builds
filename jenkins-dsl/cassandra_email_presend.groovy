// This will fail first two times in Jenkins, first the script and then the removeHeader method needs to be approved.
//     Navigate to jenkins > Manage jenkins > In-process Script Approval
//
// Deprecated from 5.0 (post CASSANDRA-18594)
msg.removeHeader("In-Reply-To")
msg.removeHeader("References")
