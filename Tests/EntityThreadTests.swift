/*
* Copyright (C) 2015 - 2016, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.io>.
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*
*	*	Redistributions of source code must retain the above copyright notice, this
*		list of conditions and the following disclaimer.
*
*	*	Redistributions in binary form must reproduce the above copyright notice,
*		this list of conditions and the following disclaimer in the documentation
*		and/or other materials provided with the distribution.
*
*	*	Neither the name of Graph nor the names of its
*		contributors may be used to endorse or promote products derived from
*		this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import XCTest
@testable import Graph

class EntityThreadTests : XCTestCase, GraphDelegate {
	var graph: Graph!

	var insertSaveExpectation: XCTestExpectation?
	var insertExpectation: XCTestExpectation?
	var insertPropertyExpectation: XCTestExpectation?
	var insertGroupExpectation: XCTestExpectation?
	var updateSaveExpectation: XCTestExpectation?
	var updatePropertyExpectation: XCTestExpectation?
	var deleteSaveExpectation: XCTestExpectation?
	var deleteExpectation: XCTestExpectation?
	var deletePropertyExpectation: XCTestExpectation?
	var deleteGroupExpectation: XCTestExpectation?

	override func setUp() {
		super.setUp()
		graph = Graph()
		graph.delegate = self
	}

	override func tearDown() {
		graph = nil
		super.tearDown()
	}

	func testAll() {
		graph.clear()
		graph.watchForEntity(types: ["T"], groups: ["G"], properties: ["P"])

		let q1: dispatch_queue_t = dispatch_queue_create("io.graph.EntityThreadTests1", DISPATCH_QUEUE_SERIAL)
		let q2: dispatch_queue_t = dispatch_queue_create("io.graph.EntityThreadTests2", DISPATCH_QUEUE_SERIAL)
		let q3: dispatch_queue_t = dispatch_queue_create("io.graph.EntityThreadTests3", DISPATCH_QUEUE_SERIAL)

		insertSaveExpectation = expectationWithDescription("Test: Save did not pass.")
		insertExpectation = expectationWithDescription("Test: Insert did not pass.")
		insertPropertyExpectation = expectationWithDescription("Test: Insert property did not pass.")
		insertGroupExpectation = expectationWithDescription("Test: Insert group did not pass.")

		let n: Entity = Entity(type: "T")

		dispatch_async(q1) { [unowned self] in
			n["P"] = 111
			n.addToGroup("G")

			self.graph.asyncSave { [unowned self] (success: Bool, error: NSError?) in
				XCTAssertTrue(success, "Cannot save the Graph: \(error)")
				self.insertSaveExpectation?.fulfill()
			}
		}

		waitForExpectationsWithTimeout(10, handler: nil)

		updateSaveExpectation = expectationWithDescription("Test: Save did not pass.")
		updatePropertyExpectation = expectationWithDescription("Test: Update did not pass.")

		dispatch_async(q2) { [unowned self] in
			n["P"] = 222

			self.graph.asyncSave { [unowned self] (success: Bool, error: NSError?) in
				XCTAssertTrue(success, "Cannot save the Graph: \(error)")
				self.updateSaveExpectation?.fulfill()
			}
		}

		waitForExpectationsWithTimeout(10, handler: nil)

		deleteSaveExpectation = expectationWithDescription("Test: Save did not pass.")
		deleteExpectation = expectationWithDescription("Test: Delete did not pass.")
		deletePropertyExpectation = expectationWithDescription("Test: Delete property did not pass.")
		deleteGroupExpectation = expectationWithDescription("Test: Delete group did not pass.")

		dispatch_async(q3) { [unowned self] in
			n.delete()

			self.graph.asyncSave { [unowned self] (success: Bool, error: NSError?) in
				XCTAssertTrue(success, "Cannot save the Graph: \(error)")
				self.deleteSaveExpectation?.fulfill()
			}
		}

		waitForExpectationsWithTimeout(10, handler: nil)
	}

	func graphDidInsertEntity(graph: Graph, entity: Entity) {
		XCTAssertTrue("T" == entity.type)
		XCTAssertTrue(entity["P"] as? Int == 111)
		XCTAssertTrue(entity.memberOfGroup("G"))
		insertExpectation?.fulfill()
	}

	func graphDidInsertEntityProperty(graph: Graph, entity: Entity, property: String, value: AnyObject) {
		XCTAssertTrue("T" == entity.type)
		XCTAssertTrue("P" == property)
		XCTAssertTrue(111 == value as? Int)
		XCTAssertTrue(entity[property] as? Int == value as? Int)
		insertPropertyExpectation?.fulfill()
	}

	func graphDidInsertEntityGroup(graph: Graph, entity: Entity, group: String) {
		XCTAssertTrue("T" == entity.type)
		XCTAssertTrue("G" == group)
		insertGroupExpectation?.fulfill()
	}

	func graphDidUpdateEntityProperty(graph: Graph, entity: Entity, property: String, value: AnyObject) {
		XCTAssertTrue("T" == entity.type)
		XCTAssertTrue("P" == property)
		XCTAssertTrue(222 == value as? Int)
		XCTAssertTrue(entity[property] as? Int == value as? Int)
		updatePropertyExpectation?.fulfill()
	}

	func graphDidDeleteEntity(graph: Graph, entity: Entity) {
		XCTAssertTrue("T" == entity.type)
		deleteExpectation?.fulfill()
	}

	func graphDidDeleteEntityProperty(graph: Graph, entity: Entity, property: String, value: AnyObject) {
		XCTAssertTrue("T" == entity.type)
		XCTAssertTrue("P" == property)
		XCTAssertTrue(222 == value as? Int)
		deletePropertyExpectation?.fulfill()
	}

	func graphDidDeleteEntityGroup(graph: Graph, entity: Entity, group: String) {
		XCTAssertTrue("T" == entity.type)
		XCTAssertTrue("G" == group)
		deleteGroupExpectation?.fulfill()
	}

	func testPerformance() {
		self.measureBlock() {}
	}
}
