import Foundation

/// Where a fact came from. Every spec that can be wrong carries one (spec 8.3).
public enum Provenance: String, Codable, Sendable, CaseIterable {
  /// A named official, press or news source states the value.
  case sourced
  /// Only a weak source, such as a fan graphic.
  case unverified
  /// Acceptable sources disagree. `alternatives` lists the other values.
  case conflicting
  /// No value.
  case unknown

  /// True when the value is confirmed by a named source.
  public var isConfirmed: Bool { self == .sourced }
}

/// One competing value for a `conflicting` field.
public struct Alternative<Value: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
  public var value: Value
  public var sourceIDs: [String]

  public init(value: Value, sourceIDs: [String]) {
    self.value = value
    self.sourceIDs = sourceIDs
  }

  enum CodingKeys: String, CodingKey {
    case value = "v"
    case sourceIDs = "sources"
  }
}

/// A value with its provenance. Drives the provenance marker everywhere in the app.
public struct FieldValue<Value: Codable & Sendable & Hashable>: Codable, Sendable, Hashable {
  public var value: Value?
  public var status: Provenance
  public var sourceIDs: [String]
  public var alternatives: [Alternative<Value>]
  public var note: String?

  public init(
    value: Value?, status: Provenance, sourceIDs: [String] = [],
    alternatives: [Alternative<Value>] = [], note: String? = nil
  ) {
    self.value = value
    self.status = value == nil ? .unknown : status
    self.sourceIDs = sourceIDs
    self.alternatives = alternatives
    self.note = note
  }

  public static var unknown: FieldValue { FieldValue(value: nil, status: .unknown) }

  enum CodingKeys: String, CodingKey {
    case value = "v"
    case status
    case sourceIDs = "sources"
    case alternatives
    case note
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let value = try c.decodeIfPresent(Value.self, forKey: .value)
    let status = try c.decode(Provenance.self, forKey: .status)
    self.value = value
    self.status = value == nil ? .unknown : status
    self.sourceIDs = try c.decodeIfPresent([String].self, forKey: .sourceIDs) ?? []
    self.alternatives = try c.decodeIfPresent([Alternative<Value>].self, forKey: .alternatives) ?? []
    self.note = try c.decodeIfPresent(String.self, forKey: .note)
  }
}
