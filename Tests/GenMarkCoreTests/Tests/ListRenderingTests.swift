import XCTest
@testable import GenMarkCore

final class ListRenderingTests: XCTestCase {
    private let parser = CMarkParser()
    
    func test_bullet_list_has_bullet_kind() {
        let md = "- Item 1\n- Item 2\n- Item 3"
        let doc = parser.parse(markdown: md)
        
        guard case let .list(kind, items) = doc.blocks.first else {
            XCTFail("Expected list block")
            return
        }
        
        XCTAssertEqual(kind, .bullet)
        XCTAssertEqual(items.count, 3)
        XCTAssertNil(items[0].checked) // Bullet items don't have checked state
    }
    
    func test_ordered_list_has_ordered_kind() {
        let md = "1. First\n2. Second\n3. Third"
        let doc = parser.parse(markdown: md)
        
        guard case let .list(kind, items) = doc.blocks.first else {
            XCTFail("Expected list block")
            return
        }
        
        guard case .ordered(let start) = kind else {
            XCTFail("Expected ordered list kind")
            return
        }
        
        XCTAssertEqual(start, 1)
        XCTAssertEqual(items.count, 3)
        XCTAssertNil(items[0].checked) // Ordered items don't have checked state
    }
    
    func test_task_list_has_task_kind_with_checked_states() {
        let md = "- [ ] Todo\n- [x] Done\n- [ ] Another todo"
        let doc = parser.parse(markdown: md)
        
        guard case let .list(kind, items) = doc.blocks.first else {
            XCTFail("Expected list block")
            return
        }
        
        XCTAssertEqual(kind, .task)
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].checked, false)
        XCTAssertEqual(items[1].checked, true)
        XCTAssertEqual(items[2].checked, false)
    }
    
    func test_list_with_inline_formatting() {
        let md = "- Item with **bold** text\n- Item with *italic* text\n- Item with `code`"
        let doc = parser.parse(markdown: md)
        
        guard case let .list(kind, items) = doc.blocks.first else {
            XCTFail("Expected list block")
            return
        }
        
        XCTAssertEqual(kind, .bullet)
        XCTAssertEqual(items.count, 3)
        
        // Each item should have a paragraph child with inline content
        for item in items {
            XCTAssertFalse(item.children.isEmpty)
            if case .paragraph(let inlines) = item.children.first {
                XCTAssertFalse(inlines.isEmpty)
            } else {
                XCTFail("Expected paragraph in list item")
            }
        }
    }
    
    func test_ordered_list_starting_number() {
        let md = "5. Fifth item\n6. Sixth item\n7. Seventh item"
        let doc = parser.parse(markdown: md)
        
        guard case let .list(kind, items) = doc.blocks.first else {
            XCTFail("Expected list block")
            return
        }
        
        guard case .ordered(let start) = kind else {
            XCTFail("Expected ordered list kind")
            return
        }
        
        // The starting number should be preserved
        XCTAssertEqual(start, 5)
        XCTAssertEqual(items.count, 3)
    }
}