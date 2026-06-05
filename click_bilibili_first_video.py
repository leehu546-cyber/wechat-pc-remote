"""Open Bilibili in Edge, click first video, exit quickly (browser stays open via detach)."""
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

options = webdriver.EdgeOptions()
options.add_experimental_option("detach", True)
driver = webdriver.Edge(options=options)

try:
    driver.get("https://www.bilibili.com")
    wait = WebDriverWait(driver, 10)
    first_video = wait.until(EC.element_to_be_clickable(
        (By.CSS_SELECTOR, ".video-list-item a, .bili-video-card a, .feed-card a, .video-card-common a")
    ))
    driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", first_video)
    driver.execute_script("arguments[0].click();", first_video)
    print("WECHAT_OK: 已打开哔哩哔哩并点击第一个视频，浏览器保持打开。")
finally:
    driver.quit()
