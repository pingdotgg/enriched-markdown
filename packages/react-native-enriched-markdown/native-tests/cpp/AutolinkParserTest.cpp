#include "MD4CParser.hpp"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

static void collect(const std::shared_ptr<Markdown::MarkdownASTNode> &node, std::vector<std::string> &urls) {
  if (node->type == Markdown::NodeType::Link)
    urls.push_back(node->attributes.at("url"));
  for (const auto &child : node->children)
    collect(child, urls);
}

int main() {
  Markdown::MD4CParser parser;
  const std::vector<std::pair<std::string, std::vector<std::string>>> cases = {
      {"http://localhost:5173/a...b?port=3000&next=foo:bar#part:2",
       {"http://localhost:5173/a...b?port=3000&next=foo:bar#part:2"}},
      {"https://devbox:8080/path", {"https://devbox:8080/path"}},
      {"Visit https://example.com/a...", {"https://example.com/a"}},
      {"(https://example.com/a_(b)).", {"https://example.com/a_(b)"}},
      {"www.example.com user@example.com", {"http://www.example.com", "mailto:user@example.com"}},
      {"www.localhost user@localhost", {}},
      {"`http://localhost:3000`", {}},
      {"[Site](https://example.com/explicit)", {"https://example.com/explicit"}},
  };
  for (const auto &[source, expected] : cases) {
    auto root = parser.parse(source);
    assert(root);
    std::vector<std::string> actual;
    collect(root, actual);
    if (actual != expected) {
      std::cerr << source << "\n";
      for (auto &url : actual)
        std::cerr << "actual: " << url << "\n";
    }
    assert(actual == expected);
  }
}
