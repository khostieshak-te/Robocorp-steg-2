*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium
Library             RPA.HTTP
Library             RPA.PDF
Library             RPA.Tables
Library             RPA.FileSystem
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault
Library             RPA.Desktop


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
        Log    ${row}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts


*** Keywords ***
Open the robot order website
    #Ask the user for the URL of the website where we order the robots
    Add text input    url    Order Website
    ${order_url}=    Run dialog
    # We're expecting the following URL:
    # https://robotsparebinindustries.com/#/robot-order
    Open Available Browser    ${order_url.url}

Get orders
    #Get the order downloads from our vault
    ${url_vault}=    Get Secret    urlcertificate
    Download    ${url_vault}[address]    target_file=orders.csv    overwrite=True
    ${orders}=    Read table from CSV    orders.csv    header=True
    RETURN    ${orders}

Close the annoying modal
    Click Button    OK

Fill the form
    [Arguments]    ${row}
    #Fill out the robot specifications based on the CSV-file
    Select From List By Index    id=head    ${row}[Head]
    Select Radio Button    body    ${row}[Body]
    Input Text    xpath=/html/body/div/div/div[1]/div/div[1]/form/div[3]/input    ${row}[Legs]
    Input Text    xpath=/html/body/div/div/div[1]/div/div[1]/form/div[4]/input    ${row}[Address]

Preview the robot
    #Wait for the button to preview the order to exist and scroll down to it if the screen size is too small, then press the button
    Scroll Element Into View    id=preview
    Click Button When Visible    id=preview
    Wait Until Element Is Visible    id=robot-preview-image

Submit the order
    #Wait for the button to submit the order to exist and scroll down to it if the screen size is too small, then press the button
    Wait Until Element Is Enabled    xpath=/html/body/div/div/div[1]/div/div[1]/form/button[2]
    Scroll Element Into View    id=order
    Click Button When Visible    id=order

Store the receipt as a PDF file
    [Arguments]    ${order}

    #Ensure that the receipt has been loaded, if it's not loaded, then that means that the robot has failed on submitting the order
    ${is_order_submitted}=    Is Element Visible    id=receipt
    WHILE    ${is_order_submitted} == False
        Submit the order
        ${is_order_submitted}=    Is Element Visible    id=receipt
    END

    #Get the receipt data
    ${order_data}=    Get Element Attribute    id=receipt    outerHTML

    #Store the PDF to the output folder
    ${pdf_path}=    Convert To String    ${OUTPUT_DIR}${/}orders${/}receipts${/}${order}.pdf
    Html To Pdf    ${order_data}    ${pdf_path}
    Log To Console    Created PDF for ${order} in location ${pdf_path}
    RETURN    ${pdf_path}

Take a screenshot of the robot
    [Arguments]    ${order}
    #Ensure that the page is loaded
    Wait Until Element Is Visible    id=robot-preview-image

    #Ensure that all images of the robot have been loaded
    ${head_loaded}=    Is Element Visible    xpath=/html/body/div/div/div[1]/div/div[2]/div/div/img[1]
    ${body_loaded}=    Is Element Visible    xpath=/html/body/div/div/div[1]/div/div[2]/div/div/img[2]
    ${legs_loaded}=    Is Element Visible    xpath=/html/body/div/div/div[1]/div/div[2]/div/div/img[3]
    WHILE    ${head_loaded} == False or ${body_loaded} == False or ${legs_loaded} == False
        ${head_loaded}=    Is Element Visible    xpath=/html/body/div/div/div[1]/div/div[2]/div/div/img[1]
        ${body_loaded}=    Is Element Visible    xpath=/html/body/div/div/div[1]/div/div[2]/div/div/img[2]
        ${legs_loaded}=    Is Element Visible    xpath=/html/body/div/div/div[1]/div/div[2]/div/div/img[3]
    END

    #Take the screenshot and return the path to be used later
    ${order_screenshot_path}=    Capture Element Screenshot
    ...    id=robot-preview-image
    ...    ${OUTPUT_DIR}${/}orders${/}images${/}${order}.png
    Log To Console    Taking Screenshot for ${order} and saving to location ${order_screenshot_path}
    RETURN    ${order_screenshot_path}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot_path}    ${pdf_path}
    #We'll embed the screenshot of the robot as a watermark to keep everything nice and tidy
    Open Pdf    ${pdf_path}
    Add Watermark Image To Pdf    ${screenshot_path}    ${pdf_path}

Go to order another robot
    #Wait until the button to order another robot is visible and click it
    Wait Until Element Is Visible    id=order-another
    Click Button    Order another robot

Create a ZIP file of the receipts
    #Create a zip-file containing the receipts for all the orders
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}${/}orders${/}receipts.zip
    Archive Folder With Zip    ${OUTPUT_DIR}${/}orders${/}receipts    ${zip_file_name}
    #Open the file once we're done and clean the folders containing receipts and images
    Open File    ${zip_file_name}
    Run Keyword If File Exists    ${zip_file_name}    Clean up files

Clean up files
    #Remove the folders and the data within them to keep everything nice and tidy
    Remove Directory    ${OUTPUT_DIR}${/}orders${/}receipts    True
    Remove Directory    ${OUTPUT_DIR}${/}orders${/}images    True
