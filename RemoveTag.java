public static void main(String[] args) {
        try (PDDocument document = PDDocument.load(new File("src/main/resources/text_tag_11.pdf"))) {
            for (PDPage page : document.getDocumentCatalog().getPages()) {
                PdfContentStreamEditor editor = new PdfContentStreamEditor(document, page) {
                    @Override
                    protected void write(ContentStreamWriter contentStreamWriter, Operator operator, List<COSBase> operands) throws IOException {
                        String operatorString = operator.getName();
                        if (TEXT_SHOWING_OPERATORS.contains(operatorString))
                        {
                            if(operands.get(0) instanceof COSString ){
                                COSString str= (COSString) operands.get(0);
                                String text=str.getString();
                                String updated= extractStringsBetweenCurlyBraces(text);
                                if(!text.equals(updated)){
                                    str.setValue(updated.getBytes());
                                }
                            }
                            if(operands.get(0) instanceof COSArray ){
                                Iterator var7 =  ((COSArray) operands.get(0)).iterator();
                                while(var7.hasNext()) {
                                    COSBase obj = (COSBase) var7.next();
                                    if (obj instanceof COSString) {
                                        COSString str= (COSString) obj;
                                        String text=str.getString();
                                        String updated= extractStringsBetweenCurlyBraces(text);
                                        str.setValue(updated.getBytes());
                                    }
                                }
                            }
                        }
                        super.write(contentStreamWriter, operator, operands);
                    }
                    final List<String> TEXT_SHOWING_OPERATORS = Arrays.asList("Tj", "'", "\"", "TJ");
                };
                editor.processPage(page);
            }
            document.save(new File("src/main/resources/text_tag_removed.pdf"));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    
    public static String extractStringsBetweenCurlyBraces(String input) {
        Pattern pattern = Pattern.compile("\\{\\{[^}]*\\}\\}|\\{\\{.*$");
        Matcher matcher = pattern.matcher(input);

        while (matcher.find()) {
            String match = matcher.group();
            String replacement = " ".repeat(match.length()+7);
            input= input.replace(match,replacement);

        }

         pattern = Pattern.compile("^.*?\\}\\}");
         matcher = pattern.matcher(input);

        while (matcher.find()) {
            String match = matcher.group();
            String replacement = " ".repeat(match.length()+7);
            input= input.replace(match,replacement);

        }

        return input;
    }
