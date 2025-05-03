import Foundation

func wildCardMatch(_ pattern: String, _ string: String) -> Bool {
    return fnmatch(pattern, string, FNM_PATHNAME | FNM_PERIOD | FNM_NOESCAPE) == 0
}