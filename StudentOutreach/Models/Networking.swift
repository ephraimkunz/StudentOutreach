//
//  Networking.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation
import os.log

// MARK: - Networking

struct Networking {

  // MARK: Internal

  let accessToken: String

  func fetchCourses() async -> [Course] {
    var request =
      URLRequest(
        url: URL(
          string: "https://canvas.instructure.com/api/v1/courses?enrollment_type=teacher&enrollment_state=active&include[]=term&include[]=sections&per_page=100"
        )!
      )
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    do {
      let (data, _) = try await URLSession.shared.data(for: request)

      let courses = try decoder.decode([Course].self, from: data)
      return courses.sorted { first, second in
        let firstString = (first.courseCode ?? "") + first
          .name + (first.term.isDefaultTerm ? "" : first.term.name) + (first.sections.first?.name ?? "")
        let secondString = (second.courseCode ?? "") + second
          .name + (second.term.isDefaultTerm ? "" : second.term.name) + (second.sections.first?.name ?? "")
        return firstString < secondString
      }
    } catch {
      logger.error("Hit error fetching courses: \(error)")
      return []
    }
  }

  /// The assignments endpoint currently returns a 500 error. See the bug tracking this: https://github.com/instructure/canvas-lms/issues/2436
  func fetchAssignments(course: Course?) async -> [Assignment] {
    guard let course else {
      return []
    }

    var request =
      URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignments?per_page=100")!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    do {
      let (data, _) = try await URLSession.shared.data(for: request)

      let assignments = try decoder.decode([Assignment].self, from: data)
      return assignments.filter { $0.published }.sorted(by: { $0.name < $1.name })
    } catch {
      logger.error("Hit error fetching assignments: \(error)")
      return []
    }
  }

  func fetchAllStudentAssignmentInfos(course: Course?) async -> [StudentAssignmentInfo] {
    guard let course else {
      return []
    }

    var results = [StudentAssignmentInfo]()
    var nextPageURL: String? = "https://canvas.instructure.com/api/v1/courses/\(course.id)/users?enrollment_type=student&include[]=enrollments&per_page=100"

    repeat {
      do {
        // Grab all students in this course (but not the test user).
        let userRequest = {
          var userRequest = URLRequest(url: URL(string: nextPageURL!)!)
          userRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
          return userRequest
        }()
        let (userData, response) = try await URLSession.shared.data(for: userRequest)
        let users = try decoder.decode([User].self, from: userData)

        for user in users {
          results.append(StudentAssignmentInfo(
            id: user.id,
            name: user.name,
            sortableName: user.sortableName,
            score: nil,
            grade: nil,
            submittedAt: nil,
            redoRequest: false,
            courseScore: user.enrollments[0].grades.currentScore,
            lastCourseActivityAt: user.enrollments[0].lastActivityAt,
          ))
        }

        nextPageURL = nextPageURLFromResponse(response)
      } catch {
        logger.error("Hit error fetching all studentAssignmentInfos: \(error)")
        return []
      }
    } while nextPageURL != nil

    return results.sorted(by: { $0.sortableName < $1.sortableName })
  }

  func fetchStudentAssignmentInfos(assignment: Assignment?, course: Course?) async -> [StudentAssignmentInfo] {
    guard let assignment, let course else {
      return []
    }

    @Sendable
    func allGradeableStudents(courseID _: Int, assignmentID _: Int) async throws -> [UserDisplay] {
      var results = [UserDisplay]()
      var nextPageURL: String? = "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignments/\(assignment.id)/gradeable_students?per_page=100"
      repeat {
        var request = URLRequest(url: URL(string: nextPageURL!)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        results.append(contentsOf: try decoder.decode([UserDisplay].self, from: data))

        nextPageURL = nextPageURLFromResponse(response)
      } while nextPageURL != nil

      return results
    }

    @Sendable
    func allSubmissions(courseID _: Int, assignmentID _: Int) async throws -> [Submission] {
      var results = [Submission]()
      var nextPageURL: String? = "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignments/\(assignment.id)/submissions?per_page=100"
      repeat {
        var request = URLRequest(url: URL(string: nextPageURL!)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        results.append(contentsOf: try decoder.decode([Submission].self, from: data))

        nextPageURL = nextPageURLFromResponse(response)
      } while nextPageURL != nil

      return results
    }

    @Sendable
    func allUsers(courseID _: Int) async throws -> [User] {
      var results = [User]()
      var nextPageURL: String? = "https://canvas.instructure.com/api/v1/courses/\(course.id)/users?enrollment_type=student&include[]=enrollments&per_page=100"
      repeat {
        var request = URLRequest(url: URL(string: nextPageURL!)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        results.append(contentsOf: try decoder.decode([User].self, from: data))

        nextPageURL = nextPageURLFromResponse(response)
      } while nextPageURL != nil

      return results
    }

    do {
      // Grab all students eligible to submit the assignment.
      async let allGradeableStudents = allGradeableStudents(courseID: course.id, assignmentID: assignment.id)

      // Grab all submissions to the assignment.
      async let allSubmissions = allSubmissions(courseID: course.id, assignmentID: assignment.id)

      // Grab all students in this course (but not the test user).
      async let allUsers = allUsers(courseID: course.id)

      let displayStudents = try await allGradeableStudents
      let submissions = try await allSubmissions
      let users = try await allUsers

      var infos = [StudentAssignmentInfo]()
      for displayStudent in displayStudents {
        let user = users.first(where: { $0.id == displayStudent.id })
        if let user {
          let submission = submissions.first(where: { $0.userId == displayStudent.id })
          let assignmentInfo = StudentAssignmentInfo(
            id: user.id,
            name: user.name,
            sortableName: user.sortableName,
            score: submission?.score,
            grade: submission?.grade,
            submittedAt: submission?.submittedAt,
            redoRequest: submission?.redoRequest ?? false,
            courseScore: user.enrollments[0].grades.currentScore,
            lastCourseActivityAt: user.enrollments[0].lastActivityAt,
          )
          infos.append(assignmentInfo)
        }
      }

      return infos.sorted(by: { $0.sortableName < $1.sortableName })
    } catch {
      logger.error("Hit error fetching studentAssignmentInfos: \(error)")
      return []
    }
  }

  /// See https://github.com/instructure/canvas-lms/blob/22b7677b3bd608197caf012ac5304c2d6311e94c/ui/shared/grading/messageStudentsWhoHelper.ts#L92C9-L92C9
  func sendMessage(course: Course, recipients: [StudentAssignmentInfo], subject: String, isGeneric: Bool, message: String) async {
    let contextCode = "course_\(course.id)"

    if isGeneric {
      // No substitutions, so just send one bulk message (like the webUI does today).
      let body = finalMessageBody(fullName: "", firstName: "", message: message)

      var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.httpMethod = "POST"

      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let postData = PostMessageData(
        recipients: recipients.map { String($0.id) },
        subject: subject,
        body: body,
        contextCode: contextCode,
      )

      do {
        let data = try encoder.encode(postData)
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
          if httpResponse.statusCode != 202 {
            logger.error("Error sending message: \(response)")
          }
        }
      } catch {
        logger.error("Hit error posting new conversation: \(error)")
      }
    } else {
      for recipient in recipients {
        let body = finalMessageBody(fullName: recipient.name, firstName: recipient.firstName, message: message)

        var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let postData = PostMessageData(recipients: [String(recipient.id)], subject: subject, body: body, contextCode: contextCode)

        do {
          let data = try encoder.encode(postData)
          request.httpBody = data

          let (_, response) = try await URLSession.shared.data(for: request)
          if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 202 {
              logger.error("Error sending message: \(response)")
            }
          }
        } catch {
          logger.error("Hit error posting new conversation: \(error)")
        }
      }
    }
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.ephraimkunz.StudentOutreach", category: "networking")

  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private func finalMessageBody(fullName: String, firstName: String, message: String) -> String {
    var message = message
    message = message.replacingOccurrences(of: Substitutions.firstName.literal, with: firstName)
    message = message.replacingOccurrences(of: Substitutions.fullName.literal, with: fullName)
    return message
  }

}

func nextPageURLFromResponse(_ response: URLResponse) -> String? {
  var result: String?
  if let response = response as? HTTPURLResponse, let link = response.value(forHTTPHeaderField: "Link") {
    let linkData = link.split(separator: ",").map { $0.split(separator: "; ") }
    if let next = linkData.first(where: { $0.contains("rel=\"next\"") }) {
      let trimSet = CharacterSet(charactersIn: "<>")
      result = next[0].trimmingCharacters(in: trimSet)
    }
  }

  return result
}
